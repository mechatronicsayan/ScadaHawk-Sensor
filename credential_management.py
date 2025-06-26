import os
import json
from cryptography.fernet import Fernet
import requests
import hashlib
import subprocess
import netifaces
import ipaddress

# Hidden file paths
CRED_FILE = os.path.expanduser("~/.credentials.json")  # Hidden in the home directory
KEY_FILE = os.path.expanduser("~/.secret.key")         # Hidden in the home directory

def get_enp0s10_address(interface):
    try:
        addresses = netifaces.ifaddresses(interface)
        return addresses[netifaces.AF_INET][0]['addr']
    except (KeyError, ValueError):
        return None

def is_valid_ipv4(ip_str):
    try:
        ipaddress.IPv4Address(ip_str)
        return True
    except ipaddress.AddressValueError:
        return False

def set_file_permissions(file_path):
    """Set restrictive permissions on a file."""
    try:
        os.chmod(file_path, 0o600)  # Owner read/write only
    except Exception as e:
        print(f"Error setting permissions on {file_path}: {e}") 

def generate_key():
    """Generate and save a key for encryption."""
    try:
        if not os.path.exists(KEY_FILE):
            key = Fernet.generate_key()
            with open(KEY_FILE, "wb") as key_file:
                key_file.write(key)
            set_file_permissions(KEY_FILE)
            print(f"Encryption key generated and saved successfully at {KEY_FILE}!")
    except Exception as e:
        print(f"Error generating key: {e}")

def load_key():
    """Load the encryption key from the hidden file."""
    try:
        if not os.path.exists(KEY_FILE):
            print(f"Key file '{KEY_FILE}' not found. Generating a new key...")
            generate_key()

        with open(KEY_FILE, "rb") as key_file:
            return key_file.read()
    except Exception as e:
        print(f"Error loading key: {e}")
        return None

def generate_sensor_id(email, mac):
    """Generate a sensor ID by hashing the username and MAC of management interface."""
    salt = email + str(mac)
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

def register_sensor(email, password, access_key):
    registration_url = "http://scadahawk.io:8000/sensor/register"
    sensor_id = str(generate_sensor_id(email, get_mac_address("enp0s3")))
    enp0s10_ip = get_enp0s10_address("enp0s10")
    if is_valid_ipv4(str(enp0s10_ip)):
        payload = {
        "sensor": {
            "userEmail": email,
            "password": password,
            "accessKey": access_key,
            "sensorId": sensor_id,
            "sensorMac": get_mac_address("enp0s3"),
            "deception": {"ip": enp0s10_ip,"interface": "enp0s10"}
            }
        }
    else:
        payload = {
        "sensor": {
            "userEmail": email,
            "password": password,
            "accessKey": access_key,
            "sensorId": sensor_id,
            "sensorMac": get_mac_address("enp0s3"),
            "deception": {"ip": "NA","interface": "enp0s10"}
            }
        }
    try:
        response = requests.post(registration_url, json=payload)
        if response.status_code == 200:
            data = response.json()
            token = data.get("token")
            userid = data.get("userId")
            if token:
                return str(token), str(userid)
            else:
                return 0
        else:
            return 0
    except requests.exceptions.RequestException as e:
        print("Error:", e)
        return 0

def save_credentials():   # Takes all the input from user regarding registration of the sensor.
    try:
        # Get user inputs
        server_ip = input("Enter server domain: ")
        server_port = input("Enter server port: ")
        username = input("Enter server username: ")
        password = input("Enter server password: ")
        email = input("Enter the user's email address: ")
        organization = input("Enter the user's organizaion: ")

        if not server_ip or not server_port or not username or not password or not email or not organization:
            print("All fields are required. Please restart the server registration process.")
            exit()

        access_key = input("Enter the access key: ")
        print("Sensor Registration in progress.")
        register_token, userid = register_sensor(email, password, access_key)
        if register_token != 0:

            # Prepare data
            credentials = {
                "server_ip": server_ip,
                "server_port": server_port,
                "username": username,
                "password": password,
                "email": email,
                "organization": organization,
                "token": register_token,
                "userId": userid
            }

            # Encrypt credentials
            key = load_key()
            if not key:
                print("Unable to load encryption key. Exiting.")
                return

            fernet = Fernet(key)
            encrypted_data = fernet.encrypt(json.dumps(credentials).encode())

            # Save encrypted credentials in a hidden file
            with open(CRED_FILE, "wb") as cred_file:
                cred_file.write(encrypted_data)

            set_file_permissions(CRED_FILE)
            print(f"Credentials saved successfully!")
        else:
            print("Registration token not generated. Please check the connectivity and restart the process.")
            exit()
    except Exception as e:
        print(f"Error saving credentials: {e}")

def load_credentials():
    """Load and decrypt credentials."""
    try:
        # Check if the credentials file exists
        if not os.path.exists(CRED_FILE):
            print(f"Credentials file '{CRED_FILE}' not found. Please save credentials first.")
            return None

        # Read encrypted data
        with open(CRED_FILE, "rb") as cred_file:
            encrypted_data = cred_file.read()

        # Decrypt data
        key = load_key()
        if not key:
            print("Unable to load encryption key. Exiting.")
            return None

        fernet = Fernet(key)
        decrypted_data = fernet.decrypt(encrypted_data)

        # Return credentials as a dictionary
        credentials = json.loads(decrypted_data.decode())
        return credentials
    except Exception as e:
        print(f"Error loading credentials: {e}")
        return None

def main():
    """Main function to save credentials."""
    print("=== ServerHawk Registration Manager ===")
    save_credentials()

if __name__ == "__main__":
    main()