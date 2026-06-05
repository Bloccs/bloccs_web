defmodule BloccsWebDev.Schemas do
  @moduledoc "Schema for the dev `orders` network."

  def register do
    Bloccs.Schema.register("Order@1", id: :string, type: :string, amount: :integer)
    :ok
  end
end

defmodule BloccsWebDev.Nodes.Ingest do
  @moduledoc false
  use Bloccs.Node, manifest: "fixtures/nodes/ingest.bloccs"
  def transform(order, _ctx), do: {:ok, order}
  def execute(order, _ctx), do: {:emit, :order, order}
end

defmodule BloccsWebDev.Nodes.Validate do
  @moduledoc false
  use Bloccs.Node, manifest: "fixtures/nodes/validate.bloccs"

  def transform(%{id: id} = order, _ctx) when is_binary(id) and id != "", do: {:ok, order}
  def transform(_order, _ctx), do: {:error, :invalid_order}

  def execute(order, _ctx), do: {:emit, :valid, order}
end

defmodule BloccsWebDev.Nodes.Route do
  @moduledoc false
  use Bloccs.Node, manifest: "fixtures/nodes/route.bloccs"

  @known ~w(retail wholesale subscription)

  def transform(order, _ctx), do: {:ok, order}

  def execute(%{type: type} = order, _ctx) do
    if type in @known, do: {:emit, :known, order}, else: {:emit, :unknown, order}
  end
end

defmodule BloccsWebDev.Nodes.Fulfill do
  @moduledoc false
  use Bloccs.Node, manifest: "fixtures/nodes/fulfill.bloccs"
  def transform(order, _ctx), do: {:ok, order}
  def execute(order, _ctx), do: {:emit, :shipped, order}
end

defmodule BloccsWebDev.Nodes.Archive do
  @moduledoc false
  use Bloccs.Node, manifest: "fixtures/nodes/archive.bloccs"
  def transform(order, _ctx), do: {:ok, order}
  def execute(order, _ctx), do: {:emit, :archived, order}
end

defmodule BloccsWebDev.Nodes.Deadletter do
  @moduledoc false
  use Bloccs.Node, manifest: "fixtures/nodes/deadletter.bloccs"
  def transform(order, _ctx), do: {:ok, order}
  def execute(order, _ctx), do: {:emit, :recorded, order}
end
