defmodule Bloccs.Web.AccessTest do
  use ExUnit.Case, async: true

  alias Bloccs.Web.Access

  describe "enabled?/2" do
    test ":all enables every feature (the free baseline)" do
      for feature <- Access.all_features() do
        assert Access.enabled?(feature, :all)
      end
    end

    test "a list enables only its members" do
      assert Access.enabled?(:networks, [:networks, :topology])
      refute Access.enabled?(:metrics, [:networks, :topology])
    end

    test "an empty list enables nothing" do
      assert Enum.all?(Access.all_features(), &(not Access.enabled?(&1, [])))
    end
  end

  describe "default resolver" do
    test "is anonymous, full-access, all-features" do
      assert Access.resolve_user(%{}) == nil
      assert Access.resolve_access(nil) == :all
      assert Access.resolve_features(nil) == :all
    end
  end
end
