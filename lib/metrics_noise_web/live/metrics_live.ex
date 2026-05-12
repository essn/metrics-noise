defmodule MetricsNoiseWeb.MetricsLive do
  use MetricsNoiseWeb, :live_view

  alias MetricsNoise.MetricsStore

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      MetricsStore.subscribe()
    end

    metrics = MetricsStore.get_all()

    {:ok,
     socket
     |> assign(:playing, false)
     |> assign(:metrics, metrics)
     |> assign(:metric_order, Map.keys(metrics))}
  end

  @impl true
  def handle_event("toggle_audio", _params, socket) do
    playing = !socket.assigns.playing

    socket =
      socket
      |> assign(:playing, playing)
      |> push_event(if(playing, do: "audio:start", else: "audio:stop"), %{})

    socket =
      if playing do
        push_event(socket, "metrics:update",
          build_audio_payload(socket.assigns.metrics, socket.assigns.metric_order))
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:metrics_updated, metrics}, socket) do
    order =
      Enum.uniq(
        socket.assigns.metric_order ++
          Enum.filter(Map.keys(metrics), &(&1 not in socket.assigns.metric_order))
      )

    audio_payload = build_audio_payload(metrics, order)

    socket =
      socket
      |> assign(:metrics, metrics)
      |> assign(:metric_order, order)
      |> push_event("metrics:update", audio_payload)

    {:noreply, socket}
  end

  defp build_audio_payload(metrics, order) do
    indexed =
      order
      |> Enum.with_index()
      |> Enum.flat_map(fn {name, index} ->
        case Map.get(metrics, name) do
          nil ->
            []

          m ->
            [
              %{
                name: name,
                value: m.value,
                normalized: MetricsStore.normalize(m.value, m.min, m.max),
                index: index
              }
            ]
        end
      end)

    %{metrics: indexed}
  end

  def sparkline_path([]), do: ""
  def sparkline_path([_]), do: ""

  def sparkline_path(history) do
    points = Enum.reverse(history)
    n = length(points)
    {min_v, max_v} = Enum.min_max(points)
    range = max(max_v - min_v, 1.0e-9)
    w = 120
    h = 32

    [{x0, y0} | rest] =
      points
      |> Enum.with_index()
      |> Enum.map(fn {v, i} ->
        x = i / (n - 1) * w
        y = h - (v - min_v) / range * h
        {Float.round(x, 1), Float.round(y, 1)}
      end)

    tail = Enum.map_join(rest, " ", fn {x, y} -> "L#{x} #{y}" end)
    "M#{x0} #{y0} #{tail}"
  end

  def format_value(v) when is_float(v) and (v >= 1000 or v <= -1000) do
    :erlang.float_to_binary(v, decimals: 0)
  end

  def format_value(v) when is_float(v) do
    :erlang.float_to_binary(v, decimals: 3)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
  end

  def format_value(v), do: to_string(v)

  @pentatonic_names ~w(C D E G A)

  def note_name(normalized, index) do
    octave = rem(index, 4) + 2
    note_idx = round(normalized * 4)
    "#{Enum.at(@pentatonic_names, note_idx)}#{octave}"
  end

  @note_colors [
    "bg-emerald-950 text-emerald-400",
    "bg-sky-950 text-sky-400",
    "bg-violet-950 text-violet-400",
    "bg-amber-950 text-amber-400"
  ]

  def note_color(index), do: Enum.at(@note_colors, rem(index, length(@note_colors)))
end
