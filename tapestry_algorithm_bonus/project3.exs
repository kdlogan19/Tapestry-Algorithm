defmodule Project3 do
    def start_project do
        [num_nodes, num_requests,failure] = System.argv()
        MainModule.start(String.to_integer(num_nodes), String.to_integer(num_requests),failure)
    end
end

Project3.start_project