defmodule AshSurface.Fixtures.Domain do
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.Fixtures.VolunteerMilestone)
  end
end

defmodule AshSurface.Fixtures.VolunteerMilestone do
  use Ash.Resource,
    domain: AshSurface.Fixtures.Domain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key(:id)
    attribute(:member_id, :string, public?: true, allow_nil?: false)
    attribute(:milestone_id, :string, public?: true, allow_nil?: false)
    attribute(:cost_physical, :integer, public?: true, allow_nil?: false)
    attribute(:reward_spiritual, :integer, public?: true, allow_nil?: false)
    attribute(:status, :string, public?: true, default: "completed")
  end

  actions do
    defaults([:read])

    create :record do
      accept([:member_id, :milestone_id, :cost_physical, :reward_spiritual])
    end
  end
end

defmodule AshSurface.Fixtures.Server do
  @moduledoc """
  Minimal ephemeral HTTP server for end-to-end consumer dispatch verification.
  """

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def get_port(pid) do
    GenServer.call(pid, :get_port)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  @impl true
  def init(_opts) do
    {:ok, listen_socket} =
      :gen_tcp.listen(0, [
        :binary,
        packet: :raw,
        active: false,
        reuseaddr: true
      ])

    {:ok, port} = :inet.port(listen_socket)

    acceptor_pid = spawn_link(fn -> accept_loop(listen_socket) end)

    {:ok, %{listen_socket: listen_socket, port: port, acceptor_pid: acceptor_pid}}
  end

  @impl true
  def handle_call(:get_port, _from, state) do
    {:reply, state.port, state}
  end

  @impl true
  def terminate(_reason, state) do
    :gen_tcp.close(state.listen_socket)
  end

  defp accept_loop(listen_socket) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, client_socket} ->
        spawn(fn -> handle_client(client_socket) end)
        accept_loop(listen_socket)

      {:error, :closed} ->
        :ok

      {:error, _reason} ->
        :ok
    end
  end

  defp handle_client(socket) do
    case read_request(socket, "") do
      {:ok, request} ->
        route_request(socket, request)

      _ ->
        :gen_tcp.close(socket)
    end
  end

  defp read_request(socket, buffer) do
    case :gen_tcp.recv(socket, 0, 3000) do
      {:ok, data} ->
        new_buffer = buffer <> data

        if String.contains?(new_buffer, "\r\n\r\n") do
          [headers_part, rest] = String.split(new_buffer, "\r\n\r\n", parts: 2)
          content_length = extract_content_length(headers_part)

          if byte_size(rest) >= content_length do
            {:ok, %{headers: headers_part, body: rest}}
          else
            read_remaining_body(socket, headers_part, rest, content_length)
          end
        else
          read_request(socket, new_buffer)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp read_remaining_body(socket, headers_part, body_acc, needed_len) do
    case :gen_tcp.recv(socket, 0, 3000) do
      {:ok, data} ->
        new_body = body_acc <> data

        if byte_size(new_body) >= needed_len do
          {:ok, %{headers: headers_part, body: new_body}}
        else
          read_remaining_body(socket, headers_part, new_body, needed_len)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_content_length(headers) do
    lines = String.split(headers, "\r\n")

    Enum.find_value(lines, 0, fn line ->
      case String.split(line, ~r/:\s*/, parts: 2) do
        [key, val] ->
          if String.downcase(key) == "content-length" do
            String.to_integer(String.trim(val))
          else
            nil
          end

        _ ->
          nil
      end
    end)
  end

  defp route_request(socket, %{headers: headers, body: body}) do
    [request_line | _] = String.split(headers, "\r\n")

    cond do
      String.starts_with?(request_line, "POST /dispatch") ->
        handle_dispatch(socket, body)

      String.starts_with?(request_line, "POST /simulate_disconnect_after_dispatch") ->
        handle_disconnect_after_dispatch(socket, body)

      true ->
        send_response(socket, 404, %{"error" => "not_found"})
    end
  end

  defp handle_dispatch(socket, body) do
    case Jason.decode(body) do
      {:ok, %{"action" => "AshSurface.Fixtures.VolunteerMilestone#record", "input" => input}} ->
        case Ash.create(AshSurface.Fixtures.VolunteerMilestone, input,
               action: :record,
               domain: AshSurface.Fixtures.Domain
             ) do
          {:ok, record} ->
            response = %{
              "success" => true,
              "data" => %{
                "id" => record.id,
                "member_id" => record.member_id,
                "milestone_id" => record.milestone_id,
                "cost_physical" => record.cost_physical,
                "reward_spiritual" => record.reward_spiritual,
                "status" => record.status
              }
            }

            send_response(socket, 200, response)

          {:error, error} ->
            send_response(socket, 422, %{"success" => false, "error" => inspect(error)})
        end

      _ ->
        send_response(socket, 400, %{"error" => "invalid_dispatch_payload"})
    end
  rescue
    e ->
      send_response(socket, 500, %{"error" => Exception.message(e)})
  end

  defp handle_disconnect_after_dispatch(socket, body) do
    # Perform mutation in the database/data layer, but abruptly abort TCP socket without response
    case Jason.decode(body) do
      {:ok, %{"input" => input}} ->
        _ =
          Ash.create(AshSurface.Fixtures.VolunteerMilestone, input,
            action: :record,
            domain: AshSurface.Fixtures.Domain
          )

        :gen_tcp.close(socket)

      _ ->
        :gen_tcp.close(socket)
    end
  rescue
    _ ->
      :gen_tcp.close(socket)
  end

  defp send_response(socket, status_code, payload) do
    json = Jason.encode!(payload)

    status_text =
      case status_code do
        200 -> "OK"
        400 -> "Bad Request"
        404 -> "Not Found"
        422 -> "Unprocessable Entity"
        500 -> "Internal Server Error"
      end

    response =
      "HTTP/1.1 #{status_code} #{status_text}\r\n" <>
        "Content-Type: application/json\r\n" <>
        "Content-Length: #{byte_size(json)}\r\n" <>
        "Connection: close\r\n\r\n" <>
        json

    :gen_tcp.send(socket, response)
    :gen_tcp.close(socket)
  end
end
