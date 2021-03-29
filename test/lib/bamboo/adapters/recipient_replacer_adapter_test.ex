defmodule Bamboo.RecipientReplacerAdapterTest do
  use ExUnit.Case

  alias Bamboo.Email
  alias Bamboo.RecipientReplacerAdapter

  @config [
    adapter: RecipientReplacerAdapter,
    inner_adapter: __MODULE__.GenericAdapter,
    recipient_replacements: ["replaced@example.com"]
  ]

  setup do
    Application.put_env(:bamboo, __MODULE__.Mailer, @config)
    Process.register(self(), :mailer_test)
    on_exit(fn -> Application.delete_env(:bamboo, __MODULE__.Mailer) end)
    :ok
  end

  defmodule GenericAdapter do
    def deliver(email, config) do
      send(:mailer_test, {:deliver, email, config})
      {:ok, email}
    end

    def handle_config(config), do: config

    def supports_attachments?(_config), do: true
  end

  defmodule(Mailer, do: use(Bamboo.Mailer, otp_app: :bamboo))

  test "replaces to addresses with configured recipients" do
    from = "sender@example.com"
    receiver_to = "receiver-to@example.com"
    receiver_cc = "receiver-cc@example.com"
    receiver_bcc = "receiver-bcc@example.com"
    email = Email.new_email(to: receiver_to, from: from, cc: receiver_cc, bcc: receiver_bcc)

    {:ok, _delivered_email} = Mailer.deliver_now(email)

    assert_received {:deliver, delivered_email, _}

    assert [{nil, "replaced@example.com"}] = delivered_email.to
    assert [] = delivered_email.cc
    assert [] = delivered_email.bcc

    assert %{
             "X-Real-To" => ["receiver-to@example.com"],
             "X-Real-Cc" => ["receiver-cc@example.com"],
             "X-Real-Bcc" => ["receiver-bcc@example.com"]
           } = delivered_email.headers
  end
end
