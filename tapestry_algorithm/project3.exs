defmodule Project3 do
    def start_project do
        [num_nodes, num_requests] = System.argv()
        MainModule.start(String.to_integer(num_nodes), String.to_integer(num_requests))
    end
end

Project3.start_project