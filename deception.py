#!/usr/bin/env python
import netifaces
from pymodbus.device import ModbusDeviceIdentification
from pymodbus.datastore import ModbusSequentialDataBlock, ModbusSlaveContext, ModbusServerContext
from pymodbus.server.sync import StartTcpServer
from pymodbus.transaction import ModbusRtuFramer, ModbusAsciiFramer, ModbusBinaryFramer
import logging

# Logging configuration
FORMAT = ('%(asctime)-15s %(threadName)-15s %(levelname)-8s %(module)-15s:%(lineno)-8s %(message)s')
logging.basicConfig(format=FORMAT)
log = logging.getLogger()
log.setLevel(logging.DEBUG)

def get_interface_ip(interface_name):
    """Retrieve the IP address of a specific network interface."""
    try:
        # Get the interface addresses
        addresses = netifaces.ifaddresses(interface_name)
        # Extract the IPv4 address
        ip_address = addresses[netifaces.AF_INET][0]['addr']
        return ip_address
    except KeyError:
        log.error(f"Interface {interface_name} not found or has no IP address assigned.")
        return None

def run_sync_server(interface_name, port=502):
    # Get the IP address of the specified interface
    ip_address = get_interface_ip(interface_name)
    if not ip_address:
        log.error("Failed to start server: IP address for interface not found.")
        return

    # Modbus data store configuration
    store = ModbusSlaveContext(
        di=ModbusSequentialDataBlock(0, [17]*100),
        co=ModbusSequentialDataBlock(0, [17]*100),
        hr=ModbusSequentialDataBlock(0, [17]*100),
        ir=ModbusSequentialDataBlock(0, [17]*100)
    )
    context = ModbusServerContext(slaves=store, single=True)

    # Modbus device identification
    identity = ModbusDeviceIdentification()
    identity.VendorName = 'Schneider Electric'
    identity.ProductCode = 'M221'
    identity.VendorUrl = 'NA'
    identity.ProductName = 'Modicon'
    identity.ModelName = 'M221'
    identity.MajorMinorRevision = '1.2.7'  # Replace with actual version if available

    # Start the Modbus TCP server
    log.info(f"Starting DeceptionHawk_modbus on {ip_address}:{port}")
    StartTcpServer(context, identity=identity, address=(ip_address, port))

if __name__ == "__main__":
    # Run the server on enp0s10 interface and port 502
    run_sync_server("enp0s10", port=502)
