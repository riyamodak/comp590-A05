# Sleeping Barber
### Brynne Delaney, Riya Modak, Jiya Jolly

Concurrency:
- Each customer, the barber, the receptionist, and the waiting room run as independent processes

Waiting Room:
- Implements a FIFO queue with 6 chairs
- Customers join and are removed when they time out

Barber Process:
- Uses a single chair
- Retrieves customers from the waiting room
- Simulates haircuts with random durations

Hot Swapping:
- The HotSwap module uses an Agent and holds the current implementations for the barber loop and customer behavior
- Behavior can be updated at runtime

Timeout Management:
- Customers start a timer upon arrival
- When picked up for service the timer is cancelled.
  - Prevents timeouts while in the barber's chair.
