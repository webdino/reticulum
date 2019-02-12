defmodule Ret.Avatar.AvatarSlug do
  use EctoAutoslugField.Slug, from: :name, to: :slug

  def get_sources(_changeset, _opts) do
    [:avatar_sid, :name]
  end
end

defmodule Ret.Avatar do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.{Avatar, Repo, OwnedFile, Account, Sids}
  alias Ret.Avatar.{AvatarSlug}

  @schema_prefix "ret0"
  @primary_key {:avatar_id, :id, autogenerate: true}

  schema "avatars" do
    field(:avatar_sid, :string)
    field(:slug, AvatarSlug.Type)
    belongs_to(:parent_avatar, Avatar, references: :avatar_id)

    field(:name, :string)
    field(:description, :string)
    field(:attributions, :map)

    field(:allow_remixing, :boolean)
    field(:allow_promotion, :boolean)
    belongs_to(:account, Account, references: :account_id)

    belongs_to(:gltf_owned_file, OwnedFile, references: :owned_file_id)
    belongs_to(:bin_owned_file, OwnedFile, references: :owned_file_id)

    belongs_to(:base_map_owned_file, OwnedFile, references: :owned_file_id)
    belongs_to(:emissive_map_owned_file, OwnedFile, references: :owned_file_id)
    belongs_to(:normal_map_owned_file, OwnedFile, references: :owned_file_id)
    belongs_to(:ao_metalic_roughness_map_owned_file, OwnedFile, references: :owned_file_id)

    field(:state, Avatar.State)

    timestamps()
  end

  def load_parents(avatar, preload_fields \\ [])

  def load_parents(%Avatar{parent_avatar: nil} = avatar, preload_fields), do: avatar |> Repo.preload(preload_fields)

  def load_parents(%Avatar{parent_avatar: %Ecto.Association.NotLoaded{}} = avatar, preload_fields) do
    avatar
    |> Repo.preload([:parent_avatar] ++ preload_fields)
    |> Map.update!(
      :parent_avatar,
      &Avatar.load_parents(&1, preload_fields)
    )
  end

  def load_parents(nil, _preload_fields), do: nil

  @doc false
  def changeset(
        %Avatar{} = avatar,
        account,
        owned_files,
        parent_avatar,
        attrs \\ %{}
      ) do
    avatar
    |> cast(attrs, [:name])
    |> validate_required([])
    |> maybe_add_avatar_sid_to_changeset
    |> unique_constraint(:avatar_sid)
    |> put_assoc(:account, account)
    |> put_assoc(:parent_avatar, parent_avatar)
    |> put_owned_files(owned_files)
    |> AvatarSlug.maybe_generate_slug()
    |> AvatarSlug.unique_constraint()
  end

  defp put_owned_files(changeset, owned_files) do
    Enum.reduce(owned_files, changeset, fn {key, file}, changes ->
      put_owned_file(changes, key, file)
    end)
  end

  defp put_owned_file(changeset, key, owned_file) do
    changeset |> put_change("#{key}_owned_file_id" |> String.to_atom(), owned_file.owned_file_id)
  end

  defp maybe_add_avatar_sid_to_changeset(changeset) do
    avatar_sid = changeset |> get_field(:avatar_sid) || Sids.generate_sid()
    put_change(changeset, :avatar_sid, "#{avatar_sid}")
  end
end
