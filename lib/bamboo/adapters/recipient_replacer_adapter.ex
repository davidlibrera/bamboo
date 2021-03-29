defmodule Bamboo.RecipientReplacerAdapter do
  @moduledoc """
  Replaces to addresses with a provided recipients list.

  It provides a wrapper for any other mailer adapter, usefull when working on releases
  machine with real email address. It simply replaces `to` addresses
  with the provided list of addresses and set original values for `to`, `cc` and `bcc`
  in headers.

  ## Example config

      # Typically done in config/staging.exs
      config :my_pp, MyAppMailer.
        adapter: Bamboo.RecipientReplacerAdapter,
        inner_adapter: Bamboo.SendGridAdapter,
        ...

      # Define a Mailer. Typically in lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end
  """

  import Bamboo.Email, only: [put_header: 3]

  @behaviour Bamboo.Adapter

  @doc false
  def deliver(email, config) do
    original_to = Map.get(email, :to)
    original_cc = Map.get(email, :cc)
    original_bcc = Map.get(email, :bcc)

    adapter = config.inner_adapter

    recipients_list =
      config.recipient_replacements
      |> Enum.map(&{nil, &1})

    email =
      email
      |> Map.put(:to, recipients_list)
      |> Map.put(:cc, [])
      |> Map.put(:bcc, [])
      |> put_header("X-Real-To", (original_to || []) |> convert_recipients_list())
      |> put_header("X-Real-Cc", (original_cc || []) |> convert_recipients_list())
      |> put_header("X-Real-Bcc", (original_bcc || []) |> convert_recipients_list())

    adapter.deliver(email, config)
  end

  @doc false
  def handle_config(config) do
    adapter = config.inner_adapter

    adapter.handle_config(config)
  end

  @doc false
  def supports_attachments?(config), do: config.adapter.supports_attachment?(config)

  defp convert_recipients_list(recipients_list) do
    Enum.map(recipients_list, fn {name, address} ->
      case name do
        nil -> address
        name -> "<#{name}>#{address}"
      end
    end)
  end
end
