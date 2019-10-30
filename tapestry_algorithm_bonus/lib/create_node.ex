defmodule CreateNode do

    @crypto_function :sha
    @no_of_bits 8

    def start_link() do
        GenServer.start_link(__MODULE__, [], name: :create_node)
    end

    def init(state) do
        {:ok, state}
    end

    def handle_call({:create_network, num_nodes}, _from, state) do
        node_list = Enum.reduce(1..num_nodes, [], fn number,bucket->
            hash_value = get_hash_value(number,num_nodes,bucket)
            [hash_value | bucket]
        end)
        #node_list = ["1001", "1167", "11BC", "11CC", "1211", "1222", "1234", "1235", "1BDF", "1F98", "5CFE", "FEBC"]
        Enum.each(node_list, fn node_hash->
            NetworkNode.start(node_hash)
            GenServer.call(getPid(node_hash),{:generate_routing_table,node_list,node_hash})
        end)
       
        #GenServer.call(getPid("1F98"),{:print_routing_table})
        #GenServer.call(getPid("1234"),{:print_routing_table})
        {:reply, :ok,node_list}
    end

    def handle_call({:add_node_to_network,num_nodes, node_number}, _from, node_list) do
        #node_hash = "1156"
        node_hash = get_hash_value(node_number,num_nodes,node_list)
        #IO.inspect node_hash, label: "new node - "
        NetworkNode.start(node_hash)
        GenServer.call(getPid(node_hash),{:update_network,node_list,node_hash},10000)
        #GenServer.call(getPid("1156"),{:print_routing_table})
        #GenServer.call(getPid("11BC"),{:print_routing_table})
        node_list = node_list ++ [node_hash]
        {:reply, :ok,node_list}
    end

    def getPid(node_id) do
        case Registry.lookup(:registry, node_id) do
        [{pid, _}] -> pid
        [] -> nil
        end
    end

    def get_hash_value(number,num_nodes,bucket) do
        hash_value = :crypto.hash(@crypto_function, Integer.to_string(number)) |> Base.encode16 |> String.slice(1..@no_of_bits)
        if(is_unique(hash_value,bucket)) do
            hash_value
        else
            get_hash_value(number+num_nodes,num_nodes,bucket)
        end
    end

    #Create hash values for the 80% of nodes
    def is_unique(new_hash_value,bucket) do
        if(new_hash_value in bucket) do
            :false
        else
            :true
        end
    end

    def handle_call({:get_node_list}, _from, node_list) do
        {:reply, node_list,node_list}
    end

    def handle_call({:print_state}, _from, state) do
        IO.inspect state
        {:reply, state,state}
    end

end
