defmodule MetricsNoiseWeb.OTLPController do
  use MetricsNoiseWeb, :controller

  alias MetricsNoise.{MetricsStore, OTLP.Parser}

  def metrics(conn, params) do
    require Logger
    Logger.info("otlp params keys: #{inspect(Map.keys(params))}")
    metrics = Parser.parse(params)
    Logger.info("otlp parsed #{length(metrics)} metrics")

    if metrics != [] do
      MetricsStore.ingest(metrics)
    end

    conn
    |> put_status(200)
    |> json(%{})
  end
end
