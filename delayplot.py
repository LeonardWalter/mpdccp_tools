import re
import matplotlib.pyplot as plt

# Path to the log file
log_file_path = "/tmp/mptest.log"

# Regular expression to match log lines
log_pattern = re.compile(r"\[\s*([\d.]+)\] DEQ\(.*\): (\w+) (\d+)")

# Dictionaries to store send, receive, and forward events
send_events = {}
receive_events = {}
forward_events = {}

# Read and parse the log file
with open(log_file_path, "r") as log_file:
    for line in log_file:
        match = log_pattern.match(line)
        if match:
            timestamp = float(match.group(1))
            event_type = match.group(2)
            event_number = int(match.group(3))

            if event_type == "send":
                send_events[event_number] = timestamp
            elif event_type == "receive":
                receive_events[event_number] = timestamp
            elif event_type == "forward":
                forward_events[event_number] = timestamp

# Calculate positive time differences between send and receive events
send_receive_diffs = []
for event_number, send_time in send_events.items():
    if event_number in receive_events:
        receive_time = receive_events[event_number]
        time_diff = receive_time - send_time
        if time_diff > 0:
            send_receive_diffs.append((event_number, time_diff))

# Sort by event number
send_receive_diffs.sort()

send_receive_diffs = send_receive_diffs[2:] if len(send_receive_diffs) > 2 else []

# Extract data for plotting
event_numbers_recv = [event[0] for event in send_receive_diffs]
time_diffs_recv = [event[1] * 1000 for event in send_receive_diffs]  # Convert to milliseconds

# Calculate positive time differences between send and forward events
send_forward_diffs = []
for event_number, send_time in send_events.items():
    if event_number in forward_events:
        forward_time = forward_events[event_number]
        time_diff = forward_time - send_time
        if time_diff > 0:
            send_forward_diffs.append((event_number, time_diff))

# Sort by event number
send_forward_diffs.sort()

send_forward_diffs = send_forward_diffs[2:] if len(send_forward_diffs) > 2 else []

# Extract data for plotting
event_numbers_fwd = [event[0] for event in send_forward_diffs]
time_diffs_fwd = [event[1] * 1000 for event in send_forward_diffs]  # Convert to milliseconds

# Plot the time differences
plt.figure(figsize=(14, 6))

# Plot send vs receive time differences
plt.subplot(1, 2, 1)
plt.plot(event_numbers_recv, time_diffs_recv, 'o', label='Δ Send/Receive')
plt.title('Time Differences between Send and Receive Events')
plt.xlabel('Packet Number')
plt.ylabel('Time Difference (ms)')
plt.grid(True)
plt.legend()

# Plot send vs forward time differences
plt.subplot(1, 2, 2)
plt.plot(event_numbers_fwd, time_diffs_fwd, 'o', label='Δ Send/Forward', color='orange')
plt.title('Time Differences between Send and Forward Events')
plt.xlabel('Packet Number')
plt.ylabel('Time Difference (ms)')
plt.grid(True)
plt.legend()

# Show plots
plt.tight_layout()
plt.show()
