assert = require 'assert'
StormRegistry = require 'stormregistry'
StormData = require 'stormdata'
util = require('util')
request = require('request-json');
extend = require('util')._extend
ip = require 'ip'
async = require 'async'
util = require 'util'


IPManager = require('./IPManager')
node = require('./Node')
switches = require('./Switches')
test = require('./Test')


#Log handler
log = require('./utils/logger').getLogger()
log.info "Topology Logger test message"
x = 0
sindex = 1

## Global IP Manager for  -- To be relooked the design
#MGMT_SUBNET = "10.0.3.0"
#WAN_SUBNET = "172.16.1.0"
#LAN_SUBNET = "10.10.10.0"


#============================================================================================================
class TestRegistry extends StormRegistry
    constructor: (filename) ->
        @on 'load', (key,val) ->
            #log.debug "restoring #{key} with:",val
            entry = new TestData key,val
            if entry?
                entry.saved = true
                @add entry

        @on 'removed', (entry) ->
            entry.destructor() if entry.destructor?

        super filename

    add: (data) ->
        return unless data instanceof TestData
        entry = super data.id, data

    update: (data) ->        
        super data.id, data    

    get: (key) ->
        entry = super key
        return unless entry?

        if entry.data? and entry.data instanceof TestData
            entry.data.id = entry.id
            entry.data
        else
            entry

#============================================================================================================

#============================================================================================================

class TestData extends StormData
    TestSchema =
        name: "Test"
        type: "object"        
        #additionalProperties: true
        properties:                        
            name: {type:"string", required:true}
            tests:
                type: "array"
                items:
                    name: "test"
                    type: "object"
                    required: true
                    properties:
                        sourcenodes :
                            type: "array"
                            items:
                                type: "string"
                                required: true
                        destnodes :
                            type: "array"
                            items:
                                type: "string"
                                required: true
                        traffictype: {type:"string", required:true}            
                        starttime:  {type:"number", required:false}    
                        duration:  {type:"number", required:true}                           
                        trafficconfig:
                            type: "object"
                            required: true

    constructor: (id, data) ->
        super id, data, TestSchema


#============================================================================================================
class TopologyRegistry extends StormRegistry
    constructor: (filename) ->
        @on 'load', (key,val) ->
            #log.debug "restoring #{key} with:",val
            entry = new TopologyData key,val
            if entry?
                entry.saved = true
                @add entry

        @on 'removed', (entry) ->
            entry.destructor() if entry.destructor?

        super filename

    add: (data) ->
        return unless data instanceof TopologyData
        entry = super data.id, data

    update: (data) ->        
        super data.id, data    

    get: (key) ->
        entry = super key
        return unless entry?

        if entry.data? and entry.data instanceof TopologyData
            entry.data.id = entry.id
            entry.data
        else
            entry

#============================================================================================================

class TopologyData extends StormData
    TopologySchema =
        name: "Topology"
        type: "object"        
        #additionalProperties: true
        properties:                        
            name: {type:"string", required:true}
            switches:
                type: "array"
                items:
                    name: "switch"
                    type: "object"
                    required: true
                    properties:
                        name: {type:"string", required:false}            
                        type:  {type:"string", required:false}                                                            
            nodes:
                type: "array"
                items:
                    name: "node"
                    type: "object"
                    required: true
                    properties:
                            name: {type:"string", required:true}            
                            type: {type:"string", required:false}
            links:
                type: "array"
                items:
                    name: "node"
                    type: "object"
                    required: true            
                    properties:                
                        type: {type:"string", required:true}
                        switches:
                            type : "array"                     
                            required: false
                            items:
                                type : "object"
                                required: false
                        connected_nodes:
                            type: "array"
                            required: false
                            items:
                                type: "object"
                                required: false
                                properties:
                                    name:{"type":"string", "required":true}

    constructor: (id, data) ->
        super id, data, TopologySchema

#============================================================================================================
class Topology   

    constructor :() ->        
        @config = {}
        @sysconfig = {}
        @status = {}
        @statistics = {}    

        @switchobj = []
        @nodeobj =  []
        @linksobj = []
        @testobjs = []
        log.info "New Topology object is created"

    systemconfig:(config) ->
        @sysconfig = extend {},config
    # Object Iterator functions... Async each is used in many place.. hence cannot be removed currently.
    # To be converted in to Hash model.
    getNodeObjbyName:(name) ->
        log.debug "getNodeObjbyName - input " + name
        retun null unless name?
        for obj in @nodeobj
            log.debug "getNodeObjbyName - checking with " + obj.config.name
            if obj.config.name is name
                log.debug "getNodeObjbyName found " + obj.config.name
                return obj
        log.debug "getNodeObjbyName not found " + name
        return null

    getSwitchObjbyName:(name) ->
        log.debug "getSwitchObjbyName input  " + name
        retun null unless name?
        for obj in @switchobj
            log.debug "getSwitchObjbyName iteraition from the objectarray " + obj.config.name
            if obj.config.name is name
                log.debug "getSwitchObjbyName found " + obj.config.name
                return obj
        log.debug "getSwitchObjbyName not found " + name
        return null

    getSwitchObjbyUUID:(uuid) ->
        for obj in @switchobj
            log.debug "getSwitchObjbyUUID " + obj.uuid
            if obj.uuid is uuid
                log.debug "getSwitchObjbyUUID found " + obj.uuid
                return obj
        return null

    getNodeObjbyUUID:(uuid) ->
        for obj in @nodeobj
            log.debug "getNodeObjbyUUID" + obj.uuid
            if obj.uuid is uuid
                log.debug "getNodeObjbyUUID found " + obj.config.uuid
                return obj
        return null


    createSwitches :(cb)->
        async.each @switchobj, (sw,callback) =>
            log.info "createing a  switch " + sw.config.name
            sw.create (result) =>   
                #Todo:  Result value - Error Check to be done.
                log.debug "create switch result " + JSON.stringify result
                callback()
        ,(err) =>
            if err
                log.error "Error occured on createswitches function " + JSON.stringify err
                cb(false)
            else
                log.info "create switches function completed "
                cb (true)

    startSwitches :(cb)->
        async.each @switchobj, (sw,callback) =>
            log.info "starting a switch " + sw.config.name
            sw.start (result) =>   
                #Todo : Result vaue to be checked.
                log.info "start switch result " + JSON.stringify result
            #this callback place to be relooked
            callback()
        ,(err) =>
            if err
                log.error "error occured " + JSON.stringify err
                cb(false)
            else
                log.info "start switches all are processed "
                cb (true)

    #create and start the nodes
    # The node creation process is async.  node create (create) call immediately respond with "creation-in-progress"
    # creation process may take few minutes dependes on the VM SIZE.
    # poll the node status(getStatus) function, to get the creation status.  Once its created, the node will be 
    # started with (start ) function.
    # 
    # Implementation:
    #  async.each is used to process all the nodes.
    #  async.until is used for poll the status  until the node creation is success. once creation is success it start the node.

    createNodes :(cb)->    
        async.each @nodeobj, (n,callback) =>
            log.info "createing a node " + n.config.name
            
            n.create (result) =>   
                log.info "create node result " + JSON.stringify result
                #check continuosly till we get the creation status value 
                create = false
                async.until(
                    ()->
                        return create
                    (repeat)->
                        n.getstatus (result)=>
                            log.info "node creation #{n.config.name} status " + result.data.status
                            unless result.data.status is "creation-in-progress"
                                create = true
                                n.start (result)=>                    
                                    log.info "node start #{n.config.name} result " + JSON.stringify result
                                    return
                            #something wrong on node creation
                            if result.data.status is "failed"  
                                return new Error "node creation failed"

                            setTimeout(repeat, 15000);
                    (err)->                        
                        log.info "createNodes completed"
                        callback(err)                        
                )
        ,(err) =>
            if err
                log.error "createNodes error occured " + err
                cb(false)
            else
                log.info "createNodes all are processed "
                cb (true)

    ###
    #currently not used
    #
    provisionNodes :(cb)->
        async.each @nodeobj, (n,callback) =>
            log.info "provisioning a node #{n.uuid}"
            n.provision (result) =>   
                #Todo : Result to be checked.
                log.info "provision node #{n.uuid} result  " + JSON.stringify  result
                callback()
        ,(err) =>
            if err
                log.error "ProvisionNodes error occured " + JSON.stringify err
                cb(false)
            else
                log.info "provisionNodes all are processed "
                cb (true)
    ###
    destroyNodes :()->
        #@tmparray = []
        #@destroySwithes()
        log.info "destroying the Nodes"

        async.each @nodeobj, (n,callback) =>
            log.info "delete node #{n.uuid}"
            n.del (result) =>                
                #@tmparray.push result
                #Todo: result to be checked
                callback()
        ,(err) =>
            if err
                log.error  "destroy nodes error occured " + JSON.stringify err
                return false
            else
                log.info "destroyNodes all are processed " + @tmparray
                return true
    
    destroySwitches :()->
        #@tmparray = []
        #@destroySwithes()
        log.info "destroying the Switches"

        async.each @switchobj, (n,callback) =>
            log.info "delete switch #{n.uuid}"
            n.del (result) =>                
                #Todo result to be checked
                #@tmparray.push result
                callback()
        ,(err) =>
            if err
                log.error "Destroy switches error occured " +  JSON.stringify err
                return false
            else
                log.info "Destroy Switches all are processed " + @tmparray
                return true

    #Create Links  
    createNodeLinks :(cb)->
        #travel each node and travel each interface 
        #get bridgename and vethname
        # call the api to add virtual interface to the switch
        async.each @nodeobj, (n,callback) =>
            log.info "create a Link for a node " + n.config.name
            #travelling each interface

            for ifmap in n.config.ifmap
                if ifmap.veth?
                    obj = @getSwitchObjbyName(ifmap.brname)
                    if obj is null
                        assert "switch object #{swn.name} is not present in switch object array...failed in createnodelinks function"    
                    if obj?
                        obj.connect ifmap.veth , (res) =>
                            log.info "Link connect result" + JSON.stringify res
            callback()             
        ,(err) =>
            if err
                log.error "createNodeLinks error occured " + JSON.stringify err
                cb(false)
            else
                log.info "createNodeLinks  all are processed "
                cb (true)


    #createSwitchLinks
    createSwitchLinks :(cb)->
        #travel each switch object and call connect tapinterfaces        
        async.each @switchobj, (sw,callback) =>
            log.info "create a interconnection  switch Link"            
            sw.connectTapInterfaces (res)=>
                log.info "result" , res
            callback()    

        ,(err) =>
            if err
                log.error "createSwitchLinks error occured " + JSON.stringify err
                cb(false)
            else
                log.info "createSwitchLinks  all are processed "
                cb (true)



    ConfigureLinkChars:(cb)->
        #travel each node object and call setLinkChars
        log.info "Topology - configuring the Node to Switch Link characteristics .. "        
        async.each @nodeobj, (obj,callback) =>        
            obj.setLinkChars (result)=>
                log.info "Topology - node setLinkChars result " + result
            callback()
        ,(err) =>
            if err
                log.error "ConfigureLinkChars error occured " + JSON.stringify err
                cb(false)
            else
                log.info "ConfigureLinkChars  all are processed "
                cb (true)

    ConfigureInterSwitchLinkChars:(cb)->
        #travel each switch object and call setLinkChars
        log.info "Topology - configuring the InterSwitch Link characteristics .. "        
        async.each @switchobj, (obj,callback) =>        
            obj.setLinkChars (result)=>
                log.info "Topology - Switch setLinkChars result " + result
            callback()
        ,(err) =>
            if err
                log.error "ConfigureLinkChars error occured " + JSON.stringify err
                cb(false)
            else
                log.info "ConfigureLinkChars  all are processed "
                cb (true)


    buildSwitchObjects :()->
        log.info "processing the input switches array " + JSON.stringify @config.switches
        if @config.switches?            
            log.info "Topology - creating the switches "
            for sw in @config.switches   
                sw.make = @sysconfig.switchtype
                #sw.ports = 2
                unless sw.type is "wan"
                    sw.controller = @sysconfig.controller if @sysconfig.controller?
                log.info "Topology - creating a new switch  " + JSON.stringify sw
                obj = new switches(sw)
                @switchobj.push obj
                log.info "Topology - successfully created a switch < #{obj.config.name} > & pushed in to switchobj array "


    buildNodeObjects :()->
        log.info "processing the input nodes array " + JSON.stringify @config.nodes
        for val in @config.nodes
            #appending virtualization type and reference image name in the node json
            val.virtualization = @sysconfig.virtualization
            val.image = @sysconfig.lxcimage
            log.info "Topology - creating a new node " + JSON.stringify val

            obj = new node(val)
            log.info "Topology - successfully created a new node object " + obj.config.name
            mgmtip = @ipmgr.getFreeMgmtIP() 
            log.info "Topology - Assigning the mgmtip #{mgmtip} to the node #{obj.config.name}"
            obj.addMgmtInterface mgmtip , '255.255.255.0'
            log.info "Topology - Pushed the node obj  #{obj.config.name} in to the object array"    
            @nodeobj.push obj        


    buildLanLink: (val)->
        x = 1
        log.info "Topology - building  a LAN link " +  JSON.stringify val
        temp = @ipmgr.getFreeLanSubnet()  
        log.info "Topology - Lan Free subnet is " + JSON.stringify temp
        for sw in val.switches         
            #switch object
            log.info "Topology - iterating the switch present in the lan link " + sw.name
            swobj = @getSwitchObjbyName(sw.name)
            if swobj is null
                assert "switch object #{sw.name} is not present in switch object array...something went wrong."
            if sw.connected_nodes?
                for n in  sw.connected_nodes
                    log.info "Topology - iterating the connected_nodes in the switch #{sw.name} " + JSON.stringify n
                    obj = @getNodeObjbyName(n.name)
                    if obj is null
                        assert "node object #{n.name} is not present in node object array...something went wrong."
                    if obj?                            
                        if obj.config.type is "router"
                            startaddress = temp.firstAddress
                        else
                            startaddress = temp.iparray[x++]  
                        log.info "Topology -  #{obj.config.name} Lan address " + startaddress
                        obj.addLanInterface(sw.name, startaddress, temp.subnetMask, temp.firstAddress, n.config)
                        log.info "Topology - #{obj.config.name} added the Lan interface" 
        
    buildInterSwitchLink:(val)->
        index = 0
        log.info "Topology - building  a Interswitch link " +  JSON.stringify val
        for sw in val.switches
            #switch object
            log.info "Topology - iterating the switch present in link for interconnecting the switches " + sw.name
            swobj = @getSwitchObjbyName(sw.name)
            if swobj is null
                assert "switch object #{sw.name} is not present in switch object array...something went wrong."
            
            if sw.connected_switches?
                for n in  sw.connected_switches 
                    obj = @getSwitchObjbyName(n.name)
                    if obj?                         

                        srctaplink = "#{sw.name}_t#{swobj.tapindex}"
                        dsttaplink = "#{n.name}_t#{obj.tapindex}"                                                        
                        #swobj.createTapInterfaces srctaplink,dsttaplink
                        exec = require('child_process').exec
                        command = "ip link add #{srctaplink} type veth peer name #{dsttaplink}"
                        log.info "Topology - interswitch link creation command - #{command}" 
                        exec command, (error, stdout, stderr) =>

                        #console.log "createTapinterfaces completed", result
                        swobj.addTapInterface(srctaplink,n.config)
                        obj.addTapInterface(dsttaplink,null)
                        #incrementing the tap index for next interswitch links
                        swobj.tapindex++
                        obj.tapindex++

    buildWanLink:(val)->
        x = 0
        log.info "Topology - building  a WAN link " +  JSON.stringify val
        temp = @ipmgr.getFreeWanSubnet()
        #swname = "#{val.type}_#{val.connected_nodes[0].name}_#{val.connected_nodes[1].name}"
        #swname = "#{val.type}_sw#{sindex}"
        #sindex++
        #log.debug "  wan swname is "+ swname
        #obj = new switches
        #    name : swname
        #    ports: 2
        #    type : val.type
        #    make : @sysconfig.switchtype
        #    controller : @sysconfig.controller if @sysconfig.controller?
        #@switchobj.push obj
        sw = val.switches[0]
        swobj = @getSwitchObjbyName(sw.name)
        if swobj is null
            assert "switch object #{sw.name} is not present in switch object array...something went wrong."
          
        for n in  sw.connected_nodes
        #for n in  val.connected_nodes
            log.info "updating wan interface for ", n.name
            obj = @getNodeObjbyName(n.name)
            if obj?
                startaddress = temp.iparray[x++]
                obj.addWanInterface(sw.name, startaddress, temp.subnetMask, null, n.config)

    buildLinks:()->       
        log.info "processing the input data links array to build links " + JSON.stringify @config.links
        for val in @config.links                                                
            log.info "Topology - creating a link " +  JSON.stringify val
            if val.type is "lan"                                             
                @buildLanLink(val)
                @buildInterSwitchLink(val)
            if val.type is "wan"
                @buildWanLink(val)

    #Topology REST API functions
    create :(@tdata)->
        #util.log "Topology create - topodata: " + JSON.stringify @tdata                             
        @config = extend {}, @tdata.data      
        @uuid = @tdata.id
        log.info "Topology - creation is started with data :  " + JSON.stringify @config        

        @ipmgr = new IPManager(@sysconfig.wansubnet,@sysconfig.lansubnet,@sysconfig.mgmtsubnet)
        log.info "Topology - created a IP Manager object.. "

        @buildSwitchObjects()
        @buildNodeObjects()
        @buildLinks()
      
     
    run :()->
        
        log.info "TOPOLOGY--- GETTING IN TO ACTION... Executing the Topology "

        async.series([
            (callback)=>
                log.info "TOPOLOGY ---- CREATING THE SWITCHES FROM THE SWITCH OBJECTS"
                @createSwitches (res)->
                    log.info "TOPOLOGY ---- CREAET SWITCHES RESULT" + res   
                    callback(null,"CREATESWITCHES success") if res is true
                    callback new Error ('CREATESWITCHES failed')  unless res is true
            ,
            (callback)=>
                log.info "TOPOLOGY - CREATING THE NODES FROM THE NODES OBJECTS"   
                @createNodes (res)=>
                    log.info "TOPOLOGY - CREATE NODES RESULT" + res
                    callback(null,"CREATENODES success") if res is true
                    callback new Error ('CREATENODES failed')  unless res is true
            ,
            (callback)=>
                log.info "TOPOLOGY - CREATING THE NODE LINKS - ATTACHING WITH SWITCHES"   
                @createNodeLinks (res)=>
                    log.info "TOPOLOGY - CREATE NODE LINKS RESULT " + res
                    callback(null,"CREATE NODE LINKS success") if res is true
                    callback new Error ('CREATE NODE LINKS failed')  unless res is true                    
            ,
            (callback)=>
                log.info "TOPOLOGY - CREATING THE SWITCH LINKS "   
                @createSwitchLinks (res)=>
                    log.info "TOPOLOGY - CREATE SWITCH LINKS RESULT  " + res
                    callback(null,"CREATE SWITCH LINKS success") if res is true
                    callback new Error ('CREATE SWITCH LINKS failed')  unless res is true                                        
            ,
            (callback)=>
                log.info "TOPOLOGY - STARTING THE SWITCHES "   
                @startSwitches (res)=>
                    log.info "TOPOLOGY - START SWITCHES RESULT "  + res
                    callback(null,"START SWITCHES success") if res is true
                    callback new Error ('START SWITCHES failed')  unless res is true              
            ,
            (callback)=>
                log.info "TOPOLOGY - CONFIGURING THE NODE LINK characteristics "   
                @ConfigureLinkChars (res)=>
                    log.info "TOPOLOGY - CONFIG LINK NODE CHARS RESULT "  + res
                    callback(null,"CONFIG NODE LINK CHAR success") if res is true
                    callback new Error ('CONFIG NODE LINK CHARS failed')  unless res is true              
            ,
            #ConfigureInterSwitchLinkChars
            (callback)=>
                log.info "TOPOLOGY - CONFIGURING THE INTER SWITCH  LINK characteristics "   
                @ConfigureInterSwitchLinkChars (res)=>
                    log.info "TOPOLOGY - CONFIG INTER SWITCH LINK  CHARS RESULT "  + res
                    callback(null,"CONFIG INTERSWITCH LINK CHAR success") if res is true
                    callback new Error ('CONFIG INTERSWITCH  LINK CHARS failed')  unless res is true              
            ],
            (err,result)=>
                log.info "TOPOLOGY -  RUN result is  %s ", result
        )

    del :()->
        res = @destroyNodes() 
        res1 = @destroySwitches()
        return {
            "id" : @uuid
            "status" : "deleted"
        }


    get :()->
        nodestatus = []
        switchstatus = []

        for n in @nodeobj
            nodestatus.push n.get()
        for n in @switchobj
            switchstatus.push n.get()
        #"config" : @config        
        "nodes" : nodestatus
        "switches":  switchstatus    

    #Test specific functions
    createTest :(testdata)->
        #can be converted in to async model
        console.log "createTest called with " + JSON.stringify testdata

        for t in testdata.data.tests
            srcnode = @getNodeObjbyName(t.sourcenodes[0])
            sourcenodeip = srcnode.mgmtip
            destnode = @getNodeObjbyName(t.destnodes[0])
            destnodeip = destnode.lanip 

            testData =
                "testsuiteid": testdata.id
                "name" : "test_#{sourcenodeip}_#{destnodeip}"
                "source" : sourcenodeip
                "destination" : destnodeip
                "type": t.traffictype
                "starttime": t.starttime
                "duration": t.duration
                "config": t.trafficconfig
            testobj = new test(testData)
            testobj.run()
            @testobjs.push testobj     

    deleteTest :(testid)->


    getTestStatus :(testsuiteid, cb)->
        teststatus = []        
        async.each @testobjs, (obj,callback) =>  
            if obj.testsuiteid is testsuiteid   
                obj.get (result)=>
                    log.info "Topology - Switch getTestStatus result " + result
                    teststatus.push result
                    callback()
            else
                callback()
        ,(err) =>
            if err
                log.error "getTestStatus error occured " + JSON.stringify err
                cb(err)
            else
                log.info "getTestStatus  all are processed "
                cb (teststatus)

#============================================================================================================


class TopologyMaster
    constructor :() ->
        #@registry = new TopologyRegistry filename if filename?
        @registry = new TopologyRegistry
        @testregistry = new TestRegistry

        @topologyObj = {}
        @sysconfig = {}
        log.info "TopologyMaster - constructor - TopologyMaster object is created"  

    configure : (config)->        
        @sysconfig = extend {}, config
        log.debug "Topologymaster system config " + JSON.stringify @sysconfig
        
    #Topology specific REST API functions
    list : (callback) ->
        return callback @registry.list()

    create : (data, callback)->
        try	            
            topodata = new TopologyData null, data    
        catch err
            log.error "TopologyMaster - create - invalid schema " + JSON.stringify err
            return callback new Error "Invalid Input "
        finally				
            #log.info "TopologyMaster - create - topologyData " + JSON.stringify topodata 

        #finally create a project                    
        log.info "TopologyMaster - Topology Input JSON  schema check is passed " + JSON.stringify topodata
        obj = new Topology        
        obj.systemconfig @sysconfig
        obj.create topodata              
        @topologyObj[obj.uuid] = obj
        obj.run()
        return callback @registry.add topodata                
   
    del : (id, callback) ->
        obj = @topologyObj[id]
        if obj? 
            #remove the registry entry
            @registry.remove obj.uuid
            #remove the topology object entry from hash
            delete @topologyObj[id]
            #call the del method to remove the nodes, switches etc.
            result = obj.del()
            #Todo : delete the object (to avoid memory leak)- dont know how.
            #delete obj
            return callback result
        else
            return callback new Error "Unknown Topology ID"

    get : (id, callback) ->
        obj = @topologyObj[id]
        if obj? 
            return callback obj.get()
            #obj.get (result)=>
            #    return callback result

        else
            return callback new Error "Unknown Topology ID"
       
    #Device specific rest API f#unctions

    ###
    #currently not used
    deviceStats: (topolid, deviceid, callback) ->
        obj = @topologyObj[topolid]
        if obj? 
            deviceobj = obj.getNodeObjbyUUID(deviceid)
            if deviceobj?
                deviceobj.stats (result)=>
                    callback result
            else                
                callback new Error "Unknown Device ID"
        else
            callback new Error "Unknown Topology ID"
    ###

    deviceGet: (topolid, deviceid, callback) ->
        obj = @topologyObj[topolid]
        if obj? 
            deviceobj = obj.getNodeObjbyUUID(deviceid)
            if deviceobj?
                deviceobj.getstatus (result)=>
                    return callback result
            else                
                return callback new Error "Unknown Device ID"
        else
            return callback new Error "Unknown Topology ID"

    ###
    #currently not used
    deviceStatus: (topolid, deviceid, callback) ->
        obj = @topologyObj[topolid]
        if obj? 
            deviceobj = obj.getNodeObjbyUUID(deviceid)
            if deviceobj?
                deviceobj.getrunningstatus (result)=>
                    return callback result
            else                
                return callback new Error "Unknown Device ID"
        else
            return callback new Error "Unknown Topology ID"
    ###
    deviceStart: (topolid, deviceid, callback) ->
        obj = @topologyObj[topolid]
        if obj? 
            deviceobj = obj.getNodeObjbyUUID(deviceid)
            if deviceobj?
                deviceobj.start (result)=>
                    callback result
            else                
                return callback new Error "Unknown Device ID"
        else
            return callback new Error "Unknown Topology ID"


    deviceStop: (topolid, deviceid, callback) ->
        obj = @topologyObj[topolid]        
        if obj? 
            deviceobj = obj.getNodeObjbyUUID(deviceid)
            if deviceobj?
                deviceobj.stop (result)=>
                    callback result
            else                
                return callback new Error "Unknown Device ID"
        else
            return callback new Error "Unknown Topology ID"
    ###
    # currently not used
    deviceTrace: (topolid, deviceid, callback) ->
        obj = @topologyObj[topolid]        
        if obj? 
            deviceobj = obj.getNodeObjbyUUID(deviceid)
            if deviceobj?
                deviceobj.trace (result)=>
                    callback result
            else                
                return callback new Error "Unknown Device ID"
        else
            return callback new Error "Unknown Topology ID"
    ###
    deviceDelete: (topolid, deviceid, callback) ->
        obj = @topologyObj[topolid]
        if obj? 
            deviceobj = obj.getNodeObjbyUUID(deviceid)
            if deviceobj?
                deviceobj.del (result)=>    
                    return callback result
            else                
                return callback new Error "Unknown Device ID"
        else
            return callback new Error "Unknown Topology ID"

    testSuiteCreate: (topolid, data, callback) ->
        obj = @topologyObj[topolid]
        if obj? 
            try             
                testdata = new TestData null, data    
            catch err
                log.error "TopologyMaster - Test create - invalid schema " + JSON.stringify err
                return callback new Error "Invalid Input "
            finally             
                #log.info "TopologyMaster - create - testData " + JSON.stringify testdata 

            #finally create a project                    
            log.info "TopologyMaster - Test Input JSON  schema check is passed " + JSON.stringify testdata            
            obj.createTest testdata
            return callback @testregistry.add testdata

        else
            return callback new Error "Unknown Topology ID"

    

    testSuiteList: (topolid, callback) ->
        obj = @topologyObj[topolid]
        if obj? 
            return callback @testregistry.list()          
        else
            return callback new Error "Unknown Topology ID"    

    testSuiteGet: (topolid, testsuiteid, callback) ->
        obj = @topologyObj[topolid]
        if obj? 
            obj.getTestStatus testsuiteid ,(result)=>
                log.info "main routine testsuite get " , result
                return callback result
        else
            return callback new Error "Unknown Topology ID"
    testSuiteDelete: (topolid, testsuiteid, callback) ->
        obj = @topologyObj[topolid]
        if obj? 
            obj.deleteTest testsuiteid
            @testregistry.remove testsuiteid
        else
            return callback new Error "Unknown Topology ID"

#============================================================================================================
module.exports =  new TopologyMaster