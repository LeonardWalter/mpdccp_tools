import re
import matplotlib.pyplot as plt

# Path to the log file
log_file_path = "/tmp/mptest.log"

# Regular expression to match log lines
log_pattern = re.compile(r"\[\s*([\d.]+)\] DEQ\(.*\): (\w+) (\d+)")

# Lists to store send, receive, and forward events as tuples (timestamp, event_number)
send_events = []
receive_events = []
forward_events = []

# Read and parse the log file
with open(log_file_path, "r") as log_file:
    for line in log_file:
        match = log_pattern.match(line)
        if match:
            timestamp = float(match.group(1))
            event_type = match.group(2)
            event_number = int(match.group(3))

            if event_type == "send":
                send_events.append((timestamp, event_number))
            elif event_type == "receive":
                receive_events.append((timestamp, event_number))
            elif event_type == "forward":
                forward_events.append((timestamp, event_number))

# Sort events by timestamp
send_events.sort()
receive_events.sort()
forward_events.sort()

# Remove first 2 points
send_events = send_events[2:] if len(send_events) > 2 else []
receive_events = receive_events[2:] if len(receive_events) > 2 else []
forward_events = forward_events[2:] if len(forward_events) > 2 else []


# Normalize timestamps to start from zero
if receive_events:
    min_receive_time = receive_events[0][0]
else:
    min_receive_time = float('inf')

if forward_events:
    min_forward_time = forward_events[0][0]
else:
    min_forward_time = float('inf')

if send_events:
    min_send_time = send_events[0][0]
else:
    min_send_time = float('inf')

start_time = min(min_receive_time, min_forward_time, min_send_time)

# Normalize event timestamps
send_events = [(timestamp - start_time, event_number) for timestamp, event_number in send_events]
receive_events = [(timestamp - start_time, event_number) for timestamp, event_number in receive_events]
forward_events = [(timestamp - start_time, event_number) for timestamp, event_number in forward_events]

# Prepare data for plotting
send_times = [event[0] for event in send_events]
send_numbers = [event[1] for event in send_events]

receive_times = [event[0] for event in receive_events]
receive_numbers = [event[1] for event in receive_events]

forward_times = [event[0] for event in forward_events]
forward_numbers = [event[1] for event in forward_events]

# Plot the events
plt.figure(figsize=(10, 6))

# Plot send events if they exist
if send_events:
    plt.plot(send_times, send_numbers, label='Send Events', color='green')

# Plot receive events
plt.plot(receive_times, receive_numbers, label='Receive Events', color='blue')

# Plot forward events
plt.plot(forward_times, forward_numbers, label='Forward Events', color='orange')

plt.title('Send, Receive, and Forward Events')
plt.xlabel('Time (seconds)')
plt.ylabel('Packet Number')
plt.grid(True)
plt.legend()

# Show plot
plt.tight_layout()
plt.show()
