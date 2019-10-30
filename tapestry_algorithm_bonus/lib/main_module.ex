defmodule MainModule do
    def start(num_nodes, num_requests,failure) do
        Registry.start_link(keys: :unique, name: :registry)
        {:ok, create_node_pid} = CreateNode.start_link()
        IO.puts "Creating the 80% Network"
        #Create 80% Network
        network_nodes = floor(num_nodes*0.8)
        GenServer.call(create_node_pid,{:create_network, network_nodes},1000000)
        IO.puts "Adding the Remaining 20% into the Network"
        manual_network_nodes = ceil(num_nodes*0.2)
        #change the enum value
        Enum.each(1..manual_network_nodes,fn(node)-> 
            node_number = network_nodes+node
            GenServer.call(create_node_pid,{:add_node_to_network,num_nodes, node_number},100000)
        end)


        IO.puts "Starting Connections"
        node_list = GenServer.call(create_node_pid,{:get_node_list})
        node_to_kill = Enum.random(node_list)
        process_to_kill = CreateNode.getPid(node_to_kill)
        if(failure == "true") do
            IO.inspect node_to_kill, label: "deleted node"
            GenServer.call(process_to_kill, :stop_process)
            Registry.unregister(:registry, node_to_kill)
            Process.sleep(1000)
            process_to_kill = CreateNode.getPid(node_to_kill)
            #IO.inspect Process.alive?(process_to_kill), label: "is alive: "
            #IO.inspect process_to_kill
            #IO.puts "Starting Connections"
            {:ok, message_hop_pid} = MessageHoping.start()
            GenServer.call(message_hop_pid,{:start_connections, node_list -- [node_to_kill], num_requests},100000)
        else
            {:ok, message_hop_pid} = MessageHoping.start()
            GenServer.call(message_hop_pid,{:start_connections, node_list, num_requests},100000)
        end

        #GenServer.call(create_node_pid,{:print_state},1000)
    end
end