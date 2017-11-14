defmodule Metex.Server do
    require Logger
    use GenServer

    def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, :ok, opts)
    end

    def get_status(pid) do
        GenServer.call(pid, :get_status)
    end

    def reset_status(pid) do
        GenServer.cast(pid, :reset_status)
    end

    def init(:ok) do
        {:ok, %{}}
    end

    def get_temperature(pid, location) do
        GenServer.call(pid, {:location, location})
    end

    defp temperature_of(location) do
        url_for(location)
        |> HTTPoison.get
        |> parse_response
    end

    defp url_for(location) do
        "http://api.openweathermap.org/data/2.5/weather?q=#{location}&appid=#{apikey()}"
    end

    defp parse_response({:ok, %HTTPoison.Response{body: body, status_code: 200}}) do
        body
        |> JSON.decode!
        |> compute_temperature
    end

    defp parse_response(_) do
        :error
    end

    defp compute_temperature(json) do
        try do
            temp = (json["main"]["temp"] - 273.15) |> Float.round(1)
            {:ok, temp}
        rescue 
            _-> :error
        end    
    end

    defp apikey do
        "28bbe4883584f14800c546e6bd9a56be"        
    end
    
    defp update_status(old_status, location, temp) do
        case Map.has_key?(old_status, location) do
            true -> 
                Map.put(old_status, location, temp)
            false -> 
                Map.put_new(old_status, location, temp)
        end
    end

    def handle_call({:location, location}, _from, status) do
        case temperature_of(location) do
            {:ok, temp} -> 
                new_status = update_status(status, location, temp)
                {:reply, "#{temp} C",new_status}
            _-> 
                {:reply, :error, status}
        end
    end

    def handle_call(:get_status, _from, status) do
        {:reply, status, status}
    end

    def handle_cast(:reset_status, _status) do
        {:noreply, %{}}
    end
end