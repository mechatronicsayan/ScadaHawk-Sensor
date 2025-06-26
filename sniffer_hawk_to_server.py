import os
import time
import shutil
import asyncio
import websockets
import pyshark
from threading import Thread
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone, timedelta
from credential_management import load_credentials
import subprocess
import hashlib

ETH_INTERFACES = ['enp0s8','enp0s9','enp0s10']

credentials = load_credentials()
if credentials:
    SERVER_IP = credentials["server_ip"]
    SERVER_PORT = credentials["server_port"]
    SERVER_USERNAME = credentials["username"]
    SERVER_PASSWORD = credentials["password"]
    USER_EMAIL = credentials["email"]
    ORGANIZATION = credentials["organization"]
    TOKEN = "Bearer " + str(credentials["token"])
    USERID = str(credentials["userId"])

PCAP_FOLDER = '/home/Pcaps'
BACKUP_FOLDER = '/home/Pcap_Backup'
#uri = "ws://scadahawk.io:8002/ws/pps?userId=123&sensorId=456"
#SERVER_URL = f'ws://{SERVER_IP}:{SERVER_PORT}/ws/pps?userId={SERVER_USERNAME}&sensorId={SERVER_PASSWORD}'

def generate_sensor_id(username, mac):
    """Generate a sensor ID by hashing the username and MAC of management interface."""
    salt = username + str(mac)
    return "SHSID" + str(hashlib.sha256(salt.encode()).hexdigest())

def get_mac_address(interface):
    try:
        # Run the command and capture the output
        result = subprocess.run(
            ["ip", "link", "show", interface],
            capture_output=True,
            text=True,
            check=True
        )
        # Extract the MAC address using split()
        for line in result.stdout.splitlines():
            if "link/ether" in line:
                print("MAC: " + str(line.split()[1]))
                return line.split()[1]
    except subprocess.CalledProcessError:
        print("Error: Failed to get MAC address.")
        return None

SENSOR_ID = str(generate_sensor_id(USER_EMAIL, get_mac_address("enp0s3")))
print("Sensor ID: " + SENSOR_ID)

async def capture_packets(interface, queue):
    """Captures packets on the specified interface and stores them in PCAP_FOLDER."""
    file_index = 1
    loop = asyncio.get_running_loop()
    print(f"Starting packet capture for {interface}")
    while True:
        #pcap_file = os.path.join(PCAP_FOLDER, f"{interface}_{datetime.now().strftime('%Y-%m-%d_%H-%M-%S')}_capture_{file_index}.pcap")
        pcap_file = os.path.join(PCAP_FOLDER, f"{USERID}_|_{SENSOR_ID}_|_{interface}_|_{datetime.now(timezone.utc).strftime('%Y-%m-%d_%H-%M-%S')}_|_{file_index}.pcap")
        print(f"Capturing on interface {interface}, saving to {pcap_file}")

        try:
            await loop.run_in_executor(None, capture_and_save, interface, pcap_file)  # Run capture in separate thread because the capture.sniff() function is a block call.
            await queue.put(pcap_file)  # Add file to transfer queue
            print("Put to queue successful")
            file_index += 1
        except Exception as e:
            print(f"Error on {interface}: {e}")
            break

def capture_and_save(interface, pcap_file):
    """Blocking function to capture packets."""
    print("Got inside capture_and_save function")
    capture = pyshark.LiveCapture(interface=interface, output_file=pcap_file)
    print("Capture started")
    capture.sniff(packet_count=10)  # Blocking call
    print("Capture over")
    shutil.copy2(pcap_file, BACKUP_FOLDER)  # Move to backup folder

async def file_transfer_worker(queue):
    """Handles file transfers asynchronously to avoid multiple WebSocket connections."""
    while True:
        print("Got inside the file transfer function")
        local_file = await queue.get()
        await transfer_to_server(local_file)
        queue.task_done()

async def transfer_to_server(local_file):
    """Transfers a PCAP file to the WebSocket server with automatic reconnection handling."""
    max_retries = 5
    retry_delay = 5  # Seconds
    base_local_file = os.path.basename(local_file)
    parts = base_local_file.split('_|_')
    interface = parts[2]
    file_index = parts[4].split('.')[0]
    server_url = f'ws://{SERVER_IP}:{SERVER_PORT}/ws/pps?userId={USERID}&sensorId={SENSOR_ID}&interfaceNo={interface}&captureNumber={file_index}'
    headers = {
        "Authorization": TOKEN
        }
    print("Server URL: " + str(server_url))
    for attempt in range(max_retries):
        try:
            print("Starting the file transfer")
            async with websockets.connect(server_url,extra_headers=headers) as websocket:
                with open(local_file, "rb") as f:
                    print("File reading complete")
                    file_data = f.read()
                    print("Data reading in binary successful")
                await websocket.send(file_data)
                print(f"PCAP file {local_file} sent to server.")
            return  # Success, so exit function

        except websockets.ConnectionClosed as e:
            print(f"WebSocket connection closed: {e}")
        except Exception as e:
            print(f"Error connecting to WebSocket (attempt {attempt+1}/{max_retries}): {e}")
        
        await asyncio.sleep(retry_delay)

    print(f"Failed to send {local_file} after {max_retries} attempts.")

async def delete_old_files_async(folder, retention_minutes):
    """Asynchronous version of delete_old_files to avoid blocking."""
    while True:
        now = datetime.now()
        for file in os.listdir(folder):
            file_path = os.path.join(folder, file)
            if file.endswith('.pcap') and os.path.isfile(file_path):
                file_creation_time = datetime.fromtimestamp(os.path.getctime(file_path))
                if now - file_creation_time > timedelta(minutes=retention_minutes):
                    os.remove(file_path)
                    print(f"Deleted {file_path}")
        await asyncio.sleep(60)  # Non-blocking sleep

def setup_directories():
    """Ensures PCAP and backup directories exist with correct permissions."""
    os.makedirs(PCAP_FOLDER, exist_ok=True)
    os.makedirs(BACKUP_FOLDER, exist_ok=True)
    os.chown(PCAP_FOLDER, 0, 0)
    os.chown(BACKUP_FOLDER, 0, 0)
    os.chmod(PCAP_FOLDER, 0o777)
    os.chmod(BACKUP_FOLDER, 0o777)

async def start_cleanup_tasks():
    """Starts file cleanup as background async tasks."""
    asyncio.create_task(delete_old_files_async(PCAP_FOLDER, 15))
    asyncio.create_task(delete_old_files_async(BACKUP_FOLDER, 30))

async def main():
    """Main function to start packet capturing, file transfer, and cleanup processes."""
    setup_directories()

    print("All directories are set for the capture")
    queue = asyncio.Queue()
    print("Queue initiated for the packet storage")
    
    await start_cleanup_tasks()

    # Start packet capture tasks
    asyncio.create_task(capture_packets(ETH_INTERFACES[0], queue))
    print("Created Task for capturing on first interface")
    asyncio.create_task(capture_packets(ETH_INTERFACES[1], queue))
    print("Created Task for capturing on second interface")
    asyncio.create_task(capture_packets(ETH_INTERFACES[2], queue))
    print("Created Task for capturing on second interface")


    # Start file transfer worker in background
    asyncio.create_task(file_transfer_worker(queue))
    print("Created Task for file transfer to server")

    await asyncio.Event().wait()  # Keeps the event loop running forever

if __name__ == "__main__":
    asyncio.run(main())  # ✅ Starts event loop