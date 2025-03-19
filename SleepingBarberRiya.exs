defmodule HotSwap do
  @moduledoc """
  Holds the current implementations for the barber loop and the customer process.
  These functions can be updated at runtime to “hot swap” behavior.
  """
  use Agent

  def start_link do
    Agent.start_link(
      fn ->
        %{
          barber: &Barber.default_loop/1,
          customer: &Customer.default_loop/1
        }
      end,
      name: __MODULE__
    )
  end

  def get_barber, do: Agent.get(__MODULE__, & &1.barber)
  def set_barber(fun), do: Agent.update(__MODULE__, fn state -> Map.put(state, :barber, fun) end)

  def get_customer, do: Agent.get(__MODULE__, & &1.customer)
  def set_customer(fun), do: Agent.update(__MODULE__, fn state -> Map.put(state, :customer, fun) end)
end

defmodule WaitingRoom do
  @moduledoc """
  Implements a FIFO waiting room process with a fixed number of chairs.
  It handles join requests and serves customers to the barber.
  """
  def start_link(max_chairs) do
    spawn_link(fn -> loop(max_chairs, :queue.new()) end)
  end

  defp loop(max_chairs, queue) do
    receive do
      {:join, customer_pid} ->
        if :queue.len(queue) < max_chairs do
          new_queue = :queue.in(customer_pid, queue)
          IO.puts("Customer #{inspect(customer_pid)} entered the waiting room.")
          loop(max_chairs, new_queue)
        else
          IO.puts("Waiting room full. Customer #{inspect(customer_pid)} is turned away.")
          send(customer_pid, :shop_full)
          loop(max_chairs, queue)
        end

      {:request_customer, barber_pid} ->
        case :queue.out(queue) do
          {{:value, customer_pid}, new_queue} ->
            IO.puts("Sending customer #{inspect(customer_pid)} to the barber.")
            send(barber_pid, {:serve, customer_pid})
            loop(max_chairs, new_queue)
          {:empty, _} ->
            send(barber_pid, :no_customer)
            loop(max_chairs, queue)
        end
    end
  end
end

defmodule Receptionist do
  @moduledoc """
  The receptionist greets new customers and sends them to the waiting room.
  """
  def start_link(waiting_room_pid) do
    spawn_link(fn -> loop(waiting_room_pid) end)
  end

  defp loop(waiting_room_pid) do
    receive do
      {:new_customer, customer_pid} ->
        IO.puts("Receptionist greets customer #{inspect(customer_pid)}.")
        send(waiting_room_pid, {:join, customer_pid})
        loop(waiting_room_pid)
    end
  end
end

defmodule Barber do
  @moduledoc """
  The barber process repeatedly requests a customer from the waiting room.
  Its behavior is hot swappable via the HotSwap module.
  """
  def start_link(waiting_room_pid) do
    spawn_link(fn -> loop(waiting_room_pid) end)
  end

  def loop(waiting_room_pid) do
    # Get the current barber loop function from HotSwap and execute it.
    barber_fun = HotSwap.get_barber()
    barber_fun.(waiting_room_pid)
  end

  def default_loop(waiting_room_pid) do
    # Ask the waiting room for a customer.
    send(waiting_room_pid, {:request_customer, self()})

    receive do
      {:serve, customer_pid} ->
        IO.puts("Barber starts cutting hair for customer #{inspect(customer_pid)}.")
        # Simulate a haircut by sleeping a random time.
        haircut_time = :rand.uniform(2000)
        :timer.sleep(haircut_time)
        IO.puts("Barber finished haircut for customer #{inspect(customer_pid)}.")
        send(customer_pid, :haircut_done)
        loop(waiting_room_pid)

      :no_customer ->
        IO.puts("Barber finds no customer and takes a short nap.")
        :timer.sleep(1000)
        IO.puts("Barber wakes up from nap.")
        loop(waiting_room_pid)
    end
  end
end

defmodule Customer do
  @moduledoc """
  Each customer is its own process. When spawned, it uses the current
  customer process behavior from HotSwap.
  """
  def spawn_customer(receptionist_pid) do
    customer_fun = HotSwap.get_customer()
    spawn(fn -> customer_fun.(receptionist_pid) end)
  end

  def default_loop(receptionist_pid) do
    # Customer announces arrival to the receptionist.
    send(receptionist_pid, {:new_customer, self()})

    receive do
      :haircut_done ->
        IO.puts("Customer #{inspect(self())} got a haircut and leaves.")
      :shop_full ->
        IO.puts("Customer #{inspect(self())} leaves because the shop is full.")
    after
      5000 ->
        IO.puts("Customer #{inspect(self())} waited too long and leaves.")
    end
  end
end

defmodule BarberShop do
  @moduledoc """
  Main module that starts the simulation. It sets up the HotSwap agent,
  waiting room, receptionist, barber, and a customer generator.
  """
  def start do
    # Start the hot swap agent holding current implementations.
    HotSwap.start_link()

    # Start the waiting room process with 6 chairs.
    waiting_room_pid = WaitingRoom.start_link(6)

    # Start the receptionist process.
    receptionist_pid = Receptionist.start_link(waiting_room_pid)

    # Start the barber process.
    _barber_pid = Barber.start_link(waiting_room_pid)

    # Begin generating customers forever.
    spawn(fn -> customer_generator(receptionist_pid) end)
  end

  defp customer_generator(receptionist_pid) do
    # Customers arrive at random intervals.
    :timer.sleep(:rand.uniform(2000))
    Customer.spawn_customer(receptionist_pid)
    customer_generator(receptionist_pid)
  end
end

# To run the simulation, simply call:
BarberShop.start()
:timer.sleep(:infinity)
