# Software patch-panel.
class PatchPanel < Trema::Controller

  def start(_args)
    @patch = Hash.new { [] }
    @mirror = Hash.new { [] }
    logger.info 'PatchPanel started.'
  end

  def switch_ready(dpid)
    @patch[dpid].each do |port|
      delete_flow_entries dpid, port[0], port[1]
      add_flow_entries dpid, port[0], port[1]
    end
  end

  def create_patch(dpid, port_a, port_b)
    if !@patch[dpid].include?([port_a, port_b]) then
      @patch[dpid] +=  [[port_a, port_b].sort]
      add_flow_entries dpid, port_a, port_b
      return "Patch [#{port_a.to_s} <-> #{port_b.to_s}] is created."
    else
      return "Patch [#{port_a.to_s} <-> #{port_b.to_s}] already exists."
    end
  end

  def delete_patch(dpid, port_a, port_b)
    if @patch[dpid].include?([port_a, port_b]) then
      @patch[dpid] -= [[port_a, port_b].sort]
      delete_flow_entries dpid, port_a, port_b
      return "Patch [#{port_a.to_s} <-> #{port_b.to_s}] is deleted."
    else
      return "Patch [#{port_a.to_s} <-> #{port_b.to_s}] does NOT exist."
    end
  end

  def create_mirror(dpid, port_a, port_b)
    if !@mirror[dpid].include?([port_a, port_b]) then
      @mirror[dpid] += [[port_a, port_b]]
      add_mirror_entries dpid, port_a, port_b
      return "Mirror [#{port_a.to_s} -> #{port_b.to_s}] is created."
    else
      return "Mirror [#{port_a.to_s} -> #{port_b.to_s}] already exists."
    end
  end 
    
  def delete_mirror(dpid, port_a, port_b)
    if @mirror[dpid].include?([port_a, port_b]) then
      @mirror[dpid] -= [[port_a, port_b]]
      delete_mirror_entries dpid, port_a, port_b
      return "Mirror [#{port_a.to_s} -> #{port_b.to_s}] is deleted."
    else
      return "Mirror [#{port_a.to_s} -> #{port_b.to_s}] does NOT exist."
    end
  end

  def dump_connection(dpid)
     str = "Connection List\nPatches:\n" 
     @patch[dpid].each do |port|
       str += "\t#{port[0].to_s} <-> #{port[1].to_s}\n" 
     end 
     str += "Mirrors:\n" 
     @mirror[dpid].each do |port|
       str += "\t#{port[0].to_s} -> #{port[1].to_s}\n" 
     end
     return str
   end 


  private

  def add_flow_entries(dpid, port_a, port_b)
    actions_a = []
    actions_b = []
    @patch[dpid].each do |port|
      if port_a == port[0]
        actions_a.push( SendOutPort.new( port[1] ) )
      elsif port_a == port[1]
        actions_a.push( SendOutPort.new( port[0] ) )
      end
      if port_b == port[0]
        actions_b.push( SendOutPort.new( port[1] ) )
      elsif port_b == port[1]
        actions_b.push( SendOutPort.new( port[0] ) )
      end
    end
    @mirror[dpid].each do |port|
      if port_a == port[0]
        actions_a.push( SendOutPort.new( port[1] ) )
      end
      if port_b == port[1]
        actions_b.push( SendOutPort.new( port[0] ) )
      end
    end
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_a),
                      actions: actions_a)
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_b),
                      actions: actions_b)
  end

  def delete_flow_entries(dpid, port_a, port_b)
    actions_a = []
    actions_b = []
    @patch[dpid].each do |port|
      if port_a == port[0]
        actions_a.push( SendOutPort.new( port[1] ) )
      elsif port_a == port[1]
        actions_a.push( SendOutPort.new( port[0] ) )
      end
      if port_b == port[0]
        actions_b.push( SendOutPort.new( port[1] ) )
      elsif port_b == port[1]
        actions_b.push( SendOutPort.new( port[0] ) )
      end
    end
    @mirror[dpid].each do |port|
      if port_a == port[0]
        actions_a.push( SendOutPort.new( port[1] ) )
      end
      if port_b == port[0]
        actions_b.push( SendOutPort.new( port[1] ) )
      end
    end
    if actions_a == []
      send_flow_mod_delete(dpid, match: Match.new(in_port: port_a))
    else
      send_flow_mod_add(dpid,
                        match: Match.new(in_port: port_a),
                        actions: actions_a)
    end
    if actions_b == []
      send_flow_mod_delete(dpid, match: Match.new(in_port: port_b))
    else
      send_flow_mod_add(dpid,
                        match: Match.new(in_port: port_b),
                        actions: actions_b)
    end
  end

  def add_mirror_entries(dpid, port_a, port_b)
    actions_a = []
    @patch[dpid].each do |port|
      if port_a == port[0]
        actions_a.push( SendOutPort.new( port[1] ) )
      elsif port_a == port[1]
        actions_a.push( SendOutPort.new( port[0] ) )
      end
    end
    @mirror[dpid].each do |port|
      if port_a == port[0]
        actions_a.push( SendOutPort.new( port_b ) )
      end
    end
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_a),
                      actions: actions_a)
  end

  def delete_mirror_entries(dpid, port_a, port_b)
    actions_a = []
    @patch[dpid].each do |port|
      if port_a == port[0]
        actions_a.push( SendOutPort.new( port[1] ) )
      elsif port_a == port[1]
        actions_a.push( SendOutPort.new( port[0] ) )
      end
    end
    @mirror[dpid].each do |port|
      if port_a == port[0]
        actions_a.push( SendOutPort.new( port_b ) )
      end
    end
    if actions_a == []
      send_flow_mod_delete(dpid, match: Match.new(in_port: port_a))
    else
      send_flow_mod_add(dpid,
                        match: Match.new(in_port: port_a),
                        actions: actions_a)
    end
  end


end
