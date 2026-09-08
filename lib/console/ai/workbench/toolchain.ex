defmodule Console.AI.Workbench.Toolchain do
  @moduledoc """
  Allows on-the-fly querying of tools within a workbench
  """
  alias Console.Repo
  alias Console.Schema.{Workbench, WorkbenchJob, User}
  alias Console.AI.Tool
  alias Console.AI.Workbench.{Environment, Subagents}
  alias Console.AI.Tools.Workbench.Observability

  @metrics_tools [Observability.Metrics, Observability.Plrl.Metrics]
  @logs_tools [Observability.Logs, Observability.Plrl.Logs]
  @traces_tools [Observability.Traces]
  @label_tools [
    Observability.MetricsLabelSearch,
    Observability.Plrl.MetricsLabelSearch,
    Observability.Plrl.LogLabels
  ]

  def metrics(resource, name, args, %User{} = user) when is_struct(resource, WorkbenchJob) or is_struct(resource, Workbench),
    do: execute(resource, name, args, user, @metrics_tools)

  def logs(resource, name, args, %User{} = user) when is_struct(resource, WorkbenchJob) or is_struct(resource, Workbench),
    do: execute(resource, name, args, user, @logs_tools)

  def traces(resource, name, args, %User{} = user) when is_struct(resource, WorkbenchJob) or is_struct(resource, Workbench),
    do: execute(resource, name, args, user, @traces_tools)

  def labels(%Workbench{} = workbench, name, args, %User{} = user),
    do: execute(workbench, name, args, user, @label_tools)

  defp execute(resource, name, args, user, allowed) do
    tools = tools(resource, user)

    with tool when not is_nil(tool) <- Enum.find(tools, & Tool.name(&1) == name),
         {:ok, %mod{} = t} <- Tool.validate(tool, args),
         true <- mod in allowed do
      mod.structured(t)
    else
      {:error, err} -> {:error, "failed to call tool: #{name}, result: #{inspect(err)}"}
      nil -> {:error, "tool not found"}
      _ -> {:error, "tool not valid for querying on the fly"}
    end
  end

  defp tools(%WorkbenchJob{} = job, user) do
    job
    |> env()
    |> Subagents.Observability.tools(user)
  end

  defp tools(%Workbench{} = workbench, %User{} = user) do
    workbench = Repo.preload(workbench, [tools: :mcp_server])
    job = %WorkbenchJob{workbench: workbench, user: user}
    env = Environment.new(job, workbench.tools, [])
    Subagents.Observability.core_tools(job, env, user)
  end

  defp env(%WorkbenchJob{} = job) do
    job = Repo.preload(job, [workbench: [tools: :mcp_server]])
    Environment.new(job, job.workbench.tools, [])
  end
end
