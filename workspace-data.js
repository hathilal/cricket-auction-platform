/* BOUNDARY shared live workspace data bridge.
   Uses the same browser-local Supabase project configuration and session as Auction Lobby.
   No privileged keys are accepted or stored here. */
(function(){
  const tables=['auction_rooms','auction_franchises','auction_members','auction_lots','auction_bids','auction_lot_passes'];
  async function connect(){
    const url=localStorage.getItem('boundary_sb_url');
    const key=localStorage.getItem('boundary_sb_key');
    const roomCode=localStorage.getItem('boundary_active_room_code');
    if(!url||!key)return {ok:false,reason:'Connect your Supabase project in Auction Lobby first.'};
    if(!roomCode)return {ok:false,reason:'No active room is saved in this browser. Create or join a room in Auction Lobby first.'};
    if(!window.supabase?.createClient)return {ok:false,reason:'Supabase client library did not load. Check your connection and reload.'};
    const client=window.supabase.createClient(url,key);
    const {data:sessionData,error:sessionError}=await client.auth.getSession();
    if(sessionError)throw sessionError;
    if(!sessionData.session)return {ok:false,reason:'Your guest session is not available in this browser. Re-enter as a guest in Auction Lobby.'};
    const {data,error}=await client.rpc('get_room_lobby',{p_room_code:roomCode});
    if(error)throw error;
    return {ok:true,client,session:sessionData.session,room:data,roomCode};
  }
  async function watch(connection,onUpdate){
    if(!connection?.ok)return null;
    const {client,room}=connection;
    const channel=client.channel('boundary-workspace-'+room.room_id);
    tables.forEach(table=>channel.on('postgres_changes',{event:'*',schema:'public',table,filter:'room_id=eq.'+room.room_id},async()=>{try{const {data,error}=await client.rpc('get_room_lobby',{p_room_code:connection.roomCode});if(!error)onUpdate(data)}catch(e){console.error('BOUNDARY workspace refresh failed',e)}}));
    channel.subscribe();
    return channel;
  }
  window.BoundaryData={connect,watch};
})();