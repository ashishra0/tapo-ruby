# Tapo Ruby Client

A Ruby library for controlling TP-Link Tapo smart devices (P100, P110).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'tapo'
```

Or install it yourself:

```bash
gem install tapo
```

## Usage

### Basic Control

```ruby
require 'tapo'

# Connect to a device
client = Tapo::Client.new('192.168.1.100', 'your-email@example.com', 'your-password')
client.authenticate!

# Control device
client.on
client.off

# Check status
client.on?        # => true/false
client.nickname   # => "Living Room Lamp"

# Get device info
info = client.device_info
```

### Energy Monitoring (P110 only)

```ruby
# Quick access to electrical measurements
client.power_usage  # => 12.5 (watts)
client.voltage      # => 230.5 (volts) (if supported)
client.current      # => 0.054 (amps) (if supported)

energy = client.energy_usage
# => {
#   "power_w" => 12.5,                # Power in watts (W)
#   "power_kw" => 0.012,              # Power in kilowatts (kW)
#   "voltage_v" => 230.5,             # Voltage in volts (V)
#   "current_a" => 0.054,             # Current in amps (A)
#   "today_energy_wh" => 25,          # Today's energy in watt-hours (Wh)
#   "today_energy_kwh" => 0.025,      # Today's energy in kilowatt-hours (kWh)
#   "month_energy_wh" => 350,         # Month's energy in watt-hours (Wh)
#   "month_energy_kwh" => 0.350,      # Month's energy in kilowatt-hours (kWh)
#   "today_runtime_min" => 120,       # Today's runtime in minutes
#   "today_runtime_hours" => 2.0,     # Today's runtime in hours
#   "month_runtime_min" => 5400,      # Month's runtime in minutes
#   "month_runtime_hours" => 90.0     # Month's runtime in hours
# }
```

### Device Discovery

```ruby
# Find all devices on your network
devices = Tapo::Discovery.discover

devices.each do |ip|
  puts "Found device at #{ip}"
end
```
