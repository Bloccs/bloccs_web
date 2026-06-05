defmodule Bloccs.Web.Test.Demo.Inc do
  @moduledoc """
  Test fixture node: increments an integer. Paired with
  `test/support/fixtures/nodes/inc.bloccs`. Pure, no effects — three of these
  wired in series form the `demo` network the dashboard tests observe.
  """

  use Bloccs.Node, manifest: "fixtures/nodes/inc.bloccs"

  @spec transform(map(), Bloccs.Context.t()) :: {:ok, map()} | {:error, term()}
  def transform(%{n: n}, _ctx) when is_integer(n), do: {:ok, %{n: n + 1}}
  def transform(_, _ctx), do: {:error, :not_an_integer}

  @spec execute(map(), Bloccs.Context.t()) :: {:emit, atom(), map()}
  def execute(payload, _ctx), do: {:emit, :n, payload}
end

defmodule Bloccs.Web.Test.Demo do
  @moduledoc """
  Boots the `demo` fixture network for dashboard tests: registers the schema,
  then parses → validates → compiles → starts the network so it registers with
  `Bloccs.Discovery` and emits the `[:bloccs, …]` telemetry the panels read.
  """

  alias Bloccs.{Compiler, Parser, Validator}

  @network_path Path.join(__DIR__, "fixtures/networks/demo.bloccs")

  @doc "Register the demo schema (idempotent enough for repeated test setup)."
  def register_schemas do
    Bloccs.Schema.register("Num@1", n: :integer)
    :ok
  end

  @doc """
  Compile and start the `demo` network, returning its supervisor module. The
  caller is responsible for stopping it (e.g. in `on_exit`).
  """
  @spec start!() :: module()
  def start! do
    register_schemas()

    {:ok, network} = Parser.parse_network(@network_path)
    :ok = Validator.validate_network(network)
    {:ok, supervisor} = Compiler.compile_and_load(network)
    {:ok, _pid} = supervisor.start_link([])
    supervisor
  end

  @doc "The canonical input producer name for the network's exposed `seed` port."
  @spec seed_producer() :: atom()
  def seed_producer do
    Bloccs.Router.producer_name(:demo, :first, :n)
  end
end
