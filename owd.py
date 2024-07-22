import re
import matplotlib.pyplot as plt

# Path to the log file
log_file_path = "/tmp/mptest.log"

# Regular expression to match delaying log lines
delaying_pattern = re.compile(r"\[\s*([\d.]+)\] DEQ\(.*\): delaying (\d+) for (\d+) \((\d+)\)")

# Lists to store packet numbers, delay values, and values in brackets
events = []

# Read and parse the log file
with open(log_file_path, "r") as log_file:
    for line in log_file:
        match = delaying_pattern.match(line)
        if match:
            timestamp = float(match.group(1))
            packet_number = int(match.group(2))
            delay_value = int(match.group(3))
            bracket_value = int(match.group(4))

            events.append((packet_number, delay_value, bracket_value))

# Sort events by packet number
events.sort()

# Extract data for plotting
packet_numbers = [event[0] for event in events]
delay_values = [event[1] for event in events]
bracket_values = [event[2] for event in events]

# Plot the delaying events
plt.figure(figsize=(14, 6))

# Plot delay values if there are any
if delay_values:
    plt.plot(packet_numbers, delay_values, label='One Way Delay Measurement', color='blue')

# Plot bracket values if there are any
if bracket_values:
    plt.plot(packet_numbers, bracket_values, label='RTT/2 Measurement', color='orange')

plt.title('Latency Difference Estimate')
plt.xlabel('Packet Number')
plt.ylabel('Time (ms)')
plt.grid(True)

# Show legend only if there are any delay or bracket values
if delay_values or bracket_values:
    plt.legend()

# Show plot
plt.tight_layout()
plt.show()
