#第三回 課題3-1: パッチパネルの機能拡張

##提出者
氏名：木藤嵩人

##課題内容
```
パッチパネルに機能を追加しよう。

授業で説明したパッチの追加と削除以外に、以下の機能をパッチパネルに追加してください。
1.ポートのミラーリング
2.パッチとポートミラーリングの一覧

それぞれ patch_panel のサブコマンドとして実装してください。

なお 1 と 2 以外にも機能を追加した人には、ボーナス点を加点します。
```

##解答
ポートのミラーリングを実装する前に、サンプルプログラムの改良を行った。

まず、サンプルプログラムには致命的な欠陥がある。
例えば、`port1`と`port2`の間にパッチを構成すると、フローテーブルには以下のルールが記述される。
```
port1 -> port2
port2 - > port1
```
この状態で、`port1`と`port3`の間にパッチを構成した場合フローテーブルは以下のようになる。
```
port2 - > port1
port1 - > port3
port3 - > port1
```
このように、複数のパッチが構成された場合の考慮がされていないため、下記のようにハッシュテーブルを参照することで、複数のパッチが存在する場合は複数のアクションを設定するようにした。
```
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
ーーー省略ーーー
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_a),
                      actions: actions_a)
```


この他にも、下記のように操作の結果などを表示するように改良した。
```
　　def create_patch(dpid, port_a, port_b)
    if !@patch[dpid].include?([port_a, port_b]) then
      @patch[dpid] +=  [[port_a, port_b].sort]
      add_flow_entries dpid, port_a, port_b
      return "Patch [#{port_a.to_s} <-> #{port_b.to_s}] is created."
    else
      return "Patch [#{port_a.to_s} <-> #{port_b.to_s}] already exists."
    end
  end
```

###ポートのミラーリング
パッチと区別するために、ミラーリング用のハッシュテーブル`@mirror`を作成した。
`port_a`に入ってくるパケットを`port_b`に出力するサブコマンドを実装した
```
コマンド：　./bin/patch_panel create_mirror dpid port_a port_b
```
このコマンドで呼び出される`add_mirror_entries`メソッドでは、`port_a`から入ってくるパケットに関するルールを取得し、そのルールに`port_a`に入ってくるパケットを`port_b`に出力するというアクションを追加する。
ポイントは、パッチを作成するときとは違い、`port_a`側のルールのみを確認すればよいところである。

```
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
```

さらに、パッチ作成の時にもミラーリングに対応できるように`add_flow_entries`にも変更を加えた。

```
  def add_flow_entries(dpid, port_a, port_b)
    actions_a = []
    actions_b = []
ーー省略ーー
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
```

###パッチとポートミラーリングの一覧
パッチとミラーリングの一覧を表示する`dump_connection`コマンドを追加した。
```
./bin/patch_panel dump_connection dpid
```


dump_connectionメソッドは以下のようになっている。
```
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
```
最後にreturnで文字列を返している。
コマンドは`patch_panel`に以下のように記述することで追加できるが、このときにputsを利用することで返り値をコマンドを入力したターミナルに表示することができる。
```
desc 'Display connection list'
  arg_name 'dpid'
  command :dump_connection do |c|
    c.desc 'Location to find socket files'
    c.flag [:S, :socket_dir], default_value: Trema::DEFAULT_SOCKET_DIR

    c.action do |_global_options, options, args|
      dpid = args[0].hex
      puts Trema.trema_process('PatchPanel', options[:socket_dir]).controller.
        dump_connection(dpid)
    end
  end
```

###ポートのミラーリングの削除
最後に、ポートのミラーリングを削除するメソッドを追加した。ポイントとしては、パッチやミラーリングを作成する時と同様にパッチ情報とミラーリング情報を取得し、合致するルールがない場合には削除を、そうでない場合には削除したルール以外は維持されるようにした。
  def delete_flow_entries(dpid, port_a, port_b)
    actions_a = []
    actions_b = []
ーー省略ーー
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

また、同様の変更をパッチ削除のメソッドにも適用した。
