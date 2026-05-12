defmodule MetricsNoise.MetricsStore do
  use GenServer

  @topic "metrics:updates"
  @history_size 60

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def ingest(metrics) when is_list(metrics) do
    GenServer.cast(__MODULE__, {:ingest, metrics})
  end

  def get_all, do: GenServer.call(__MODULE__, :get_all)

  def subscribe, do: Phoenix.PubSub.subscribe(MetricsNoise.PubSub, @topic)

  @impl true
  def init(_), do: {:ok, %{}}

  @impl true
  def handle_cast({:ingest, metrics}, state) do
    new_state =
      Enum.reduce(metrics, state, fn %{name: name, value: value}, acc ->
        entry = Map.get(acc, name, %{value: value, history: [], min: value, max: value})

        history = Enum.take([value | entry.history], @history_size)

        updated = %{
          value: value,
          history: history,
          min: min(entry.min, value),
          max: max(entry.max, value)
        }

        Map.put(acc, name, updated)
      end)

    Phoenix.PubSub.broadcast(MetricsNoise.PubSub, @topic, {:metrics_updated, new_state})
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_all, _from, state), do: {:reply, state, state}

  def normalize(_value, min, max) when max - min < 1.0e-9, do: 0.5

  def normalize(value, min, max) do
    (value - min) / (max - min) |> max(0.0) |> min(1.0)
  end
end
