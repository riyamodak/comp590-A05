# Sleeping Barber
### Brynne Delaney, Riya Modak, Jiya Jolly

## Design Rational
We made our design modular so each part was responsible for a different aspect of the problem. These modules communicated with eachother to achieve a cohesive simulation.

**Waiting Room**:
- Customers join and are removed when they time out (5000)

**Barber Process**:
- Simulates haircuts with random durations

**Hot Swapping**:
- The HotSwap module uses an Agent and holds the current implementations for the barber loop and customer behavior
- Behavior can be updated at runtime
  - We tested hot swapping manually in the shell by updating the barber loop during runtime and ensured following processes used new behavior

**Timeout Management**:
- Customers start a timer upon arrival
- When picked up for service the timer is cancelled
  - Prevents timeouts if the customer is serviced while timer is still running

**Debugging**:
- Used `IO.puts` statements to get runtime feedback on actions
  - i.e. customer arrival, removal from queue, haircut start and finish
  - this helped us to check hot swapping, timeouts, and waiting room FIFO order
