defmodule MetricsNoiseWeb.OTLPController do
  use MetricsNoiseWeb, :controller

  alias MetricsNoise.{MetricsStore, OTLP.Parser}

  def metrics(conn, params) do
    metrics = Parser.parse(params)

    if metrics != [] do
      MetricsStore.ingest(metrics)
    end

    conn
    |> put_status(200)
    |> json(%{})
  end
end
