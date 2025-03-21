# Riya Modak, Brynne Delaney, Jiya Jolly

defmodule HotSwap do
  # holds the barber loop and the customer process

  use Agent

  def start_link do
    Agent.start_link(
      fn ->
        %{
          barber: &Barber.default_loop/1,
          customer: &Customer.default_loop/2
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

      {:leave, customer_pid} ->
        new_queue = remove_customer(queue, customer_pid)
        IO.puts("Customer #{inspect(customer_pid)} removed from waiting room.")
        loop(max_chairs, new_queue)

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

  defp remove_customer(queue, customer_pid) do
    list = :queue.to_list(queue)
    new_list = Enum.reject(list, fn pid -> pid == customer_pid end)
    :queue.from_list(new_list)
  end
end




defmodule Receptionist do
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
  def start_link(waiting_room_pid) do
    spawn_link(fn -> loop(waiting_room_pid) end)
  end

  def loop(waiting_room_pid) do
    barber_fun = HotSwap.get_barber()
    barber_fun.(waiting_room_pid)
  end

  def default_loop(waiting_room_pid) do
    # ask the waiting room for a customer
    send(waiting_room_pid, {:request_customer, self()})

    receive do
      {:serve, customer_pid} ->
        # start customer service
        send(customer_pid, :start_service)
        IO.puts("Barber starts cutting hair for customer #{inspect(customer_pid)}.")
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
  def spawn_customer(receptionist_pid, waiting_room_pid) do
    customer_fun = HotSwap.get_customer()
    spawn(fn -> customer_fun.(receptionist_pid, waiting_room_pid) end)
  end

  def default_loop(receptionist_pid, waiting_room_pid) do
    # greet receptionist
    send(receptionist_pid, {:new_customer, self()})

    # start timeout timer
    timer_ref = Process.send_after(self(), :timeout, 5000)

    receive do
      :start_service ->
        # cancel timeout timer bc service is beginning
        Process.cancel_timer(timer_ref)
        IO.puts("Customer #{inspect(self())} is now being served.")
        receive do
          :haircut_done ->
            IO.puts("Customer #{inspect(self())} got a haircut and leaves.")
        end

      :shop_full ->
        Process.cancel_timer(timer_ref)
        IO.puts("Customer #{inspect(self())} leaves because the shop is full.")

      :timeout ->
        IO.puts("Customer #{inspect(self())} waited too long and leaves.")
        send(waiting_room_pid, {:leave, self()})
    end
  end
end




defmodule BarberShop do
  def start do
    # start hot swap agent
    HotSwap.start_link()

    waiting_room_pid = WaitingRoom.start_link(6)

    receptionist_pid = Receptionist.start_link(waiting_room_pid)

    _barber_pid = Barber.start_link(waiting_room_pid)

    spawn(fn -> customer_generator(receptionist_pid, waiting_room_pid) end)
  end

  defp customer_generator(receptionist_pid, waiting_room_pid) do
    :timer.sleep(:rand.uniform(2000))
    Customer.spawn_customer(receptionist_pid, waiting_room_pid)
    customer_generator(receptionist_pid, waiting_room_pid)
  end
end





BarberShop.start()
:timer.sleep(:infinity)
