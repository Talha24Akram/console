defmodule Console.Repo.Migrations.AddDashboardSchemas do
  use Ecto.Migration

  def change do
    create table(:dashboards, primary_key: false) do
      add :id,          :uuid, primary_key: true
      add :name,        :string
      add :description, :string

      add :graphs, :map
      add :inputs, :map

      add :workbench_id, references(:workbenches, type: :uuid, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:dashboards, [:workbench_id, :name])
    create index(:dashboards, [:workbench_id])

    alter table(:monitors) do
      add :modes,   :map
      add :prompt,  :string, limit: 2048
      add :user_id, references(:watchman_users, type: :uuid)
    end

    create index(:monitors, [:user_id])
  end
end
