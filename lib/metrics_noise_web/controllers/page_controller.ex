defmodule MetricsNoiseWeb.PageController do
  use MetricsNoiseWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
