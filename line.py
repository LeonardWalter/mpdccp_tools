import re
import matplotlib.pyplot as plt

# Path to the log file
log_file_path = "/tmp/mptest.log"

# Updated regular expression to capture the optional value in brackets
log_pattern = re.compile(r"\[\s*([\d.]+)\] DEQ\(.*\): (\w+) (\d+)(?: \((\d+)\))?")

# Lists to store send, receive, and forward events as tuples (timestamp, event_number, optional_bracketed_value)
send_events = []
receive_events = []
forward_events = []
forward_bracket_values = []  # To store bracket values

# Read and parse the log file
with open(log_file_path, "r") as log_file:
    for line in log_file:
        match = log_pattern.match(line)
        if match:
            timestamp = float(match.group(1))
            event_type = match.group(2)
            event_number = int(match.group(3))
            bracket_value = match.group(4)  # This could be None if no bracket value

            if event_type == "send":
                send_events.append((timestamp, event_number))
            elif event_type == "receive":
                receive_events.append((timestamp, event_number))
            elif event_type == "forward":
                forward_events.append((timestamp, event_number))
                if bracket_value:
                    forward_bracket_values.append((timestamp, int(bracket_value)))

# Sort events by timestamp
send_events.sort()
receive_events.sort()
forward_events.sort()
forward_bracket_values.sort()

# Remove first 2 points
send_events = send_events[2:] if len(send_events) > 2 else []
receive_events = receive_events[2:] if len(receive_events) > 2 else []
forward_events = forward_events[2:] if len(forward_events) > 2 else []
forward_bracket_values = forward_bracket_values[2:] if len(forward_bracket_values) > 2 else []

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
forward_bracket_values = [(timestamp - start_time, bracket_value) for timestamp, bracket_value in forward_bracket_values]

# Prepare data for plotting
send_times = [event[0] for event in send_events]
send_numbers = [event[1] for event in send_events]

receive_times = [event[0] for event in receive_events]
receive_numbers = [event[1] for event in receive_events]

forward_times = [event[0] for event in forward_events]
forward_numbers = [event[1] for event in forward_events]

forward_bracket_times = [event[0] for event in forward_bracket_values]
forward_bracket_numbers = [event[1] for event in forward_bracket_values]

# Create a figure with 2 subplots
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 10))

# Plot send, receive, and forward events on the first subplot (ax1)
# Plot send events if they exist
if send_events:
    ax1.plot(send_times, send_numbers, label='Send Events', color='green')

# Plot receive events
ax1.plot(receive_times, receive_numbers, label='Receive Events', color='blue')

# Plot forward events
ax1.plot(forward_times, forward_numbers, label='Forward Events', color='orange')

# Set labels for the first subplot
ax1.set_title('Send, Receive, and Forward Events')
ax1.set_xlabel('Time (seconds)')
ax1.set_ylabel('Packet Number')
ax1.grid(True)
ax1.legend()

# Plot forward bracket values on the second subplot (ax2)
if forward_bracket_values:
    ax2.plot(forward_bracket_times, forward_bracket_numbers, label='Buffered Packets', linestyle='-', color='red')

# Set labels for the second subplot
ax2.set_title('Buffered Packets')
ax2.set_xlabel('Time (seconds)')
ax2.set_ylabel('Amount')
ax2.grid(True)
ax2.legend()

# Adjust layout to prevent overlap
plt.tight_layout()

# Show plot
plt.show()
