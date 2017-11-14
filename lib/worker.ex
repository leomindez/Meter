defmodule Metex.Worker do
    require Logger 

    def loop do
        receive do
            {sender_pid, location} ->
                send(sender_pid, {:ok, temperature_of(location)})
            _ -> 
                "Can't process message"
        end    
    end

    def temperatures_of(cities) do
        coordinator_pid = spawn(Metex.Coordinator, :loop, [[], Enum.count(cities)])
        
                cities
                |> Enum.each(fn city -> 
                    worker_pid = spawn(Metex.Worker, :loop, [])
                    send worker_pid, {coordinator_pid, city}
                end) 
    end

    defp temperature_of(location) do
        result = url_for(location) |> HTTPoison.get |> parse_response
        case result do
            {:ok, temp} ->
                "#{location}: #{temp} C"
            :error ->
                "#{location} not found"
        end
    end

    defp url_for(location) do
        loc = URI.encode(location)
        "http://api.openweathermap.org/data/2.5/weather?q=#{loc}&appid=#{apikey()}"
    end

    defp parse_response({:ok, %HTTPoison.Response{body: body, status_code: 200}}) do
        body
        |> JSON.decode! 
        |> compute_temperature
    end

    defp parse_response(_) do
        :error
    end

    defp compute_temperature(temp_json) do
        try do
            temp = (temp_json["main"]["temp"] - 273.15) |> Float.round(1)
            {:ok, temp}
        rescue
            _-> {:error, "It was en error getting the temperature"}
        end
    end

    defp apikey do
        "28bbe4883584f14800c546e6bd9a56be"
    end
end