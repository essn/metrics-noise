defmodule MetricsNoise.OTLP.Parser do
  @doc """
  Parses an OTLP/HTTP JSON metrics payload into a flat list of
  `%{name: string, value: float}` maps.

  Accepts the standard `resourceMetrics` envelope. Metric names are
  qualified with attributes in Prometheus label syntax:
  `metric.name{key="value",key2="value2"}`.

  Only gauge and sum data points are extracted; histograms and
  exponential histograms are skipped.
  """
  def parse(%{"resourceMetrics" => resource_metrics}) when is_list(resource_metrics) do
    Enum.flat_map(resource_metrics, &parse_resource_metrics/1)
  end

  def parse(_), do: []

  defp parse_resource_metrics(%{"scopeMetrics" => scope_metrics}) when is_list(scope_metrics) do
    Enum.flat_map(scope_metrics, &parse_scope_metrics/1)
  end

  defp parse_resource_metrics(_), do: []

  defp parse_scope_metrics(%{"metrics" => metrics}) when is_list(metrics) do
    Enum.flat_map(metrics, &parse_metric/1)
  end

  defp parse_scope_metrics(_), do: []

  defp parse_metric(%{"name" => name, "gauge" => %{"dataPoints" => dps}}) do
    Enum.map(dps, &data_point(name, &1))
  end

  defp parse_metric(%{"name" => name, "sum" => %{"dataPoints" => dps}}) do
    Enum.map(dps, &data_point(name, &1))
  end

  defp parse_metric(_), do: []

  defp data_point(name, dp) do
    value = coerce_value(dp)
    attrs = parse_attributes(dp["attributes"] || [])

    qualified_name =
      if attrs == %{} do
        name
      else
        label_str =
          attrs
          |> Enum.sort_by(&elem(&1, 0))
          |> Enum.map_join(",", fn {k, v} -> ~s(#{k}="#{v}") end)

        "#{name}{#{label_str}}"
      end

    %{name: qualified_name, value: value}
  end

  defp coerce_value(%{"asDouble" => v}) when is_number(v), do: v / 1
  defp coerce_value(%{"asInt" => v}) when is_number(v), do: v / 1

  defp coerce_value(%{"asInt" => v}) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n / 1
      :error -> 0.0
    end
  end

  defp coerce_value(_), do: 0.0

  defp parse_attributes(attrs) do
    Map.new(attrs, fn %{"key" => key, "value" => val} -> {key, any_value(val)} end)
  end

  defp any_value(%{"stringValue" => v}), do: v
  defp any_value(%{"intValue" => v}) when is_binary(v), do: v
  defp any_value(%{"intValue" => v}), do: to_string(v)
  defp any_value(%{"doubleValue" => v}), do: to_string(v)
  defp any_value(%{"boolValue" => v}), do: to_string(v)
  defp any_value(_), do: ""
end
