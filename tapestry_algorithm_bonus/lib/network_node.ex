defmodule NetworkNode do
    @no_of_bits 8
    @empty_row %{"0" => [],"1" => [], "2" => [], "3" => [], "4" => [], "5" => [], "6" => [], "7" => [],"8" => [],"9" => [],"A" => [], "B" => [],"C" => [],"D" => [],"E" => [],"F" => []}
    @hex_value "0123456789ABCDEF"

    def start(node_hash) do
        GenServer.start_link(__MODULE__,[], name: {:via, Registry, {:registry, node_hash}})
    end

    def init(state) do
        {:ok, state}
    end

    def handle_call({:generate_routing_table,node_list,node_hash},_from, state)do
        #routing table for 4 levels
        routing_table = %{}
        filled_table = change_routing_table(routing_table,node_list,node_hash,@no_of_bits) #changeto8
        {:reply, state,{filled_table,[]}}
    end

    def change_routing_table(routing_table,node_list,node_hash,0), do: routing_table

    def change_routing_table(routing_table,node_list,node_hash,row_num) do
        nth_row_list = Enum.filter(node_list,fn(nodes) -> String.slice(nodes,0,row_num-1)==String.slice(node_hash,0,row_num-1) end)
        row_map = %{}
        nth_row_map = get_row_map(row_map,nth_row_list,node_hash,row_num,15)
        node_list = node_list -- nth_row_list
        routing_table = put_in(routing_table[row_num],nth_row_map)
        change_routing_table(routing_table,node_list,node_hash,row_num-1)
    end

    def get_row_map(row_map,nth_row_list,node_hash,row_num,-1), do: row_map

    def get_row_map(row_map,nth_row_list,node_hash,row_num,col_num) do
        #finding list of values eligible for 1 column
        value = Enum.filter(nth_row_list, fn(x) ->  String.at(x,row_num-1) == String.at(@hex_value,col_num) end)

        #find the node that is nearest
        int_hashvalue = List.to_integer(node_hash |> Kernel.to_charlist(),16)
         if(value != []) do
          {hash_value,_diff} = Enum.min_by(Enum.map(value, fn x -> {x, abs(List.to_integer(x |> to_charlist(),16) - int_hashvalue) } end), fn({x,y}) -> y end)
          row_map = put_in(row_map[String.at(@hex_value,col_num)],hash_value)
          get_row_map(row_map,nth_row_list,node_hash,row_num,col_num-1)
        else
          row_map = put_in(row_map[String.at(@hex_value,col_num)],value)
          get_row_map(row_map,nth_row_list,node_hash,row_num,col_num-1)
        end
    end

    def handle_call({:update_network,node_list,node_hash},_from,state) do
        nearest_node = find_nearest_node_list(node_hash,node_list,@no_of_bits)
        #IO.puts "#{node_hash} - nearest node #{nearest_node}"
        nearest_node_routing_table = GenServer.call(getPid(nearest_node),{:get_routing_table})
        #IO.inspect nearest_node_routing_table, label: "nearest_node_routing_table"
        index = Enum.find(1..@no_of_bits, fn x -> (String.at(node_hash,x - 1) != String.at(nearest_node,x-1)) end)
        #IO.inspect index, label: "unmatched index"
        self_routing_table = copy_routing_table(%{},nearest_node_routing_table,index,node_hash,@no_of_bits)
        self_routing_table = put_in(self_routing_table[index][String.at(nearest_node,index-1)], nearest_node)
        self_routing_table = put_in(self_routing_table[@no_of_bits][String.at(node_hash,@no_of_bits-1)], node_hash)
        #IO.inspect self_routing_table, label: node_hash
        GenServer.cast(getPid(nearest_node),{:multicast_presence,node_hash,index})
        #Process.sleep(3000)
        '''
        Enum.each(node_list,fn(node) -> 
            GenServer.cast(getPid(node),{:update_routing_table,node_hash,node})
        end)
        '''
        {:reply,:ok,{self_routing_table,[]}}
    end

    def copy_routing_table(self_routing_table,nearest_node_routing_table,index,node_hash,0), do: self_routing_table

    def copy_routing_table(self_routing_table,nearest_node_routing_table,index,node_hash,map_length) do
        if(map_length>index) do
            self_routing_table = put_in(self_routing_table[map_length], @empty_row)
            copy_routing_table(self_routing_table,nearest_node_routing_table,index,node_hash,map_length-1)
        else
            self_routing_table = put_in(self_routing_table[map_length], nearest_node_routing_table[map_length])
            copy_routing_table(self_routing_table,nearest_node_routing_table,index,node_hash,map_length-1)
        end
    end

    def find_nearest_node_list(node_hash, node_list,length) do
        nearest_node_list = Enum.filter(node_list,fn(nodes) -> String.slice(nodes,0,length-1)==String.slice(node_hash,0,length-1) end)
        if(nearest_node_list != [] && nearest_node_list != nil) do
            find_nearest_node(nearest_node_list,node_hash)
        else
            find_nearest_node_list(node_hash, node_list,length-1)
        end
    end

    def find_nearest_node(nearest_node_list,node_hash) do
        nearest_node = Enum.min_by(nearest_node_list, fn(node)-> 
            abs(List.to_integer(node |> Kernel.to_charlist(),16) - List.to_integer(node_hash |> Kernel.to_charlist(),16))
        end)
        nearest_node
    end

    def handle_call({:get_routing_table},_from, {routing_table,count_list}) do
        {:reply, routing_table,{routing_table,count_list}}
    end

    def handle_cast({:multicast_presence, new_node,row_num},{routing_table, count_list}) do
        update_routing_table(new_node,routing_table)
        [self_node_id] = Registry.keys(:registry, self())
        if(row_num<=@no_of_bits+1) do
            Enum.each(row_num..@no_of_bits, fn(row)->
                Enum.each(0..15, fn(col) ->
                    node = routing_table[row][String.at(@hex_value,col)]
                     if(node != [] && node != self_node_id && node != nil) do
                        #IO.puts "#{self_node_id} : #{routing_table[row][String.at(@hex_value,col)]}- #{row_num}"
                        GenServer.cast(getPid(node),{:multicast_presence,new_node,row_num+1})
                     end
                 end) 
             end) 
        end
        {:noreply,{routing_table, count_list} }
    end

    def update_routing_table(new_node,routing_table) do
        [node] = Registry.keys(:registry,self())
        index = Enum.find(1..@no_of_bits, fn x -> (String.at(node,x - 1) != String.at(new_node,x-1)) end)
        temp  = routing_table[index][String.at(new_node, index-1)]
        if(temp != [] && temp != nil) do
            int_node = List.to_integer(node |> Kernel.to_charlist(),16)
            int_new_node = List.to_integer(new_node |> Kernel.to_charlist(),16)
            int_temp = List.to_integer(temp |> Kernel.to_charlist(),16)
            if(abs(int_new_node - int_node) < abs(int_temp - int_node)) do
                GenServer.cast(self(),{:nearest,index,new_node})
            end
        else
            GenServer.cast(self(),{:nearest,index,new_node})
        end
    end

    def handle_cast({:nearest,index,new_node},{routing_table,count_list}) do
        routing_table = put_in(routing_table[index][String.at(new_node, index-1)],new_node)
        {:noreply, {routing_table,count_list}}
    end

    def handle_cast({:start_searching,node_list,source_node, num_request},{routing_table,count_list}) do
        #IO.inspect self(), label: "source pid"
        #IO.inspect routing_table, label: source_node
        #GenServer.cast(self(),{:send_request,source_node,source_node,"1235",0,num_request,node_list})
        Enum.each(1..num_request, fn(request_number) -> 
            #IO.inspect self(), label: "source pid in task"
            #IO.puts "#{source_node} - #{request_number}"
            GenServer.cast(self(),{:send_request,source_node,source_node,Enum.random(node_list),0,num_request,node_list})
        end)
        {:noreply,{routing_table,count_list}}
    end

    def handle_cast({:send_request,source_node,current_node,destination_node,count,num_request,node_list},{routing_table,count_list}) do
        #IO.inspect current_node, label: "current node"
        if(current_node == destination_node) do
            GenServer.cast(getPid(source_node),{:connection_complete, count,num_request})
        else
            index = Enum.find(1..@no_of_bits, fn x -> (String.at(current_node,x - 1) != String.at(destination_node,x-1)) end)
            node_in_rt  = routing_table[index][String.at(destination_node, index-1)]
            node_pid = getPid(node_in_rt)
            if(node_pid != nil) do
                #IO.inspect node_pid,label: node_in_rt
                GenServer.cast(node_pid,{:send_request,source_node,node_in_rt,destination_node,count+1,num_request,node_list})
            else
                nearest_node = find_nearest_node_list(node_in_rt,node_list,@no_of_bits)
                IO.inspect nearest_node, label: "nearest node"
                #IO.inspect routing_table, label: "before update"
                #IO.inspect nearest_node, label: "nearest node to #{node_in_rt}"
                routing_table = put_in(routing_table[index][String.at(node_in_rt, index-1)],[])
                routing_table = modify_routing_table(nearest_node,routing_table)
                #IO.inspect routing_table, label: "after update"
                GenServer.cast(getPid(nearest_node),{:send_request,source_node,nearest_node,destination_node,count+1,num_request,node_list})
                {:noreply,{routing_table,count_list}}
            end
        end
        {:noreply,{routing_table,count_list}}
    end

    def modify_routing_table(node_to_insert,routing_table) do
        [node] = Registry.keys(:registry,self())
        index = Enum.find(1..@no_of_bits, fn x -> (String.at(node,x - 1) != String.at(node_to_insert,x-1)) end)
        temp  = routing_table[index][String.at(node_to_insert, index-1)]
        routing_table = put_in(routing_table[index][String.at(node_to_insert, index-1)],node_to_insert)
        #IO.inspect routing_table, label: [node]
        routing_table
    end

    def handle_cast({:connection_complete, count,num_request}, {routing_table,count_list}) do
        #IO.inspect count_list, label: "hop count"
        if(length(count_list) == num_request-1) do
            count_list = [count|count_list]
            #IO.inspect Enum.max(count_list), label: "max count"
            #IO.inspect getPid(:message_hops), label: "max hop pid"
            send(getPid(:message_hops), {:max,Enum.max(count_list)})
        end
        {:noreply,{routing_table, [count|count_list]}}
    end

    def getPid(node_id) do
        case Registry.lookup(:registry, node_id) do
        [{pid, _}] -> pid
        [] -> nil
        end
    end

    def handle_call({:print_routing_table},_from,state)do
        #IO.inspect state, label: Registry.keys(:registry,self())
        {:reply,state,state}
    end

    def handle_call(:stop_process, _from, state) do
        {:stop, :normal,:ok, state}
    end 

    def terminate(reason, _status) do
    IO.puts "Process Exited"
    :ok 
    end 
end
