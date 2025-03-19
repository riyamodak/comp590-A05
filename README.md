# Sleeping Barber Simulation in Elixir

This project implements the classic sleeping barber problem using Elixir processes with hot-swappable behavior.

Design Rationale

Concurrency:
Each customer, the barber, the receptionist, and the waiting room run as independent processes.
Waiting Room:
Implements a FIFO queue with 6 chairs.
Customers join and, if necessary, are removed when they time out.
Barber Process:
Uses a single cutting chair.
Retrieves customers from the waiting room.
Simulates haircuts with random durations.
Hot Swapping:
The HotSwap module (using an Agent) holds the current implementations for the barber loop and customer behavior.
Behavior can be updated at runtime (e.g., via HotSwap.set_barber/1).
Timeout Management:
Customers start a timer upon arrival.
When picked up for service (via a :start_service message), the timer is cancelled.
Prevents timeouts while in the barber's chair.