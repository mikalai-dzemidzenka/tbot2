for /l %%x in (0, 1, 50) do (
   IF EXIST tbotcar%%x.pwn DEL tbotcar%%x.pwn /s  
   IF EXIST tbotfoot%%x.pwn DEL tbotfoot%%x.pwn /s
   (echo #include ^<a_npc^>
   echo NextPlayback^(^) StartRecordingPlayback^(PLAYER_RECORDING_TYPE_DRIVER,"tbotcar%%x"^);
   echo public OnRecordingPlaybackEnd^(^) NextPlayback^(^);
   echo public OnNPCSpawn^(^) NextPlayback^(^);) > tbotcar%%x.pwn

   (echo #include ^<a_npc^>
   echo NextPlayback^(^) StartRecordingPlayback^(PLAYER_RECORDING_TYPE_ONFOOT,"tbotfoot%%x"^);
   echo public OnRecordingPlaybackEnd^(^) NextPlayback^(^);
   echo public OnNPCSpawn^(^) NextPlayback^(^);) > tbotfoot%%x.pwn

   IF EXIST tbotcarsingle%%x.pwn DEL tbotcarsingle%%x.pwn /s  
   IF EXIST tbotfootsingle%%x.pwn DEL tbotfootsingle%%x.pwn /s
   (echo #include ^<a_npc^>
   echo NextPlayback^(^) StartRecordingPlayback^(PLAYER_RECORDING_TYPE_DRIVER,"tbotcarsingle%%x"^);
   echo public OnNPCSpawn^(^) NextPlayback^(^);) > tbotcarsingle%%x.pwn

   (echo #include ^<a_npc^>
   echo NextPlayback^(^) StartRecordingPlayback^(PLAYER_RECORDING_TYPE_ONFOOT,"tbotfootsingle%%x"^);
   echo public OnNPCSpawn^(^) NextPlayback^(^);) > tbotfootsingle%%x.pwn

   start ../pawno/pawncc.exe tbotcar%%x.pwn
   start ../pawno/pawncc.exe tbotfoot%%x.pwn
   start ../pawno/pawncc.exe tbotcarsingle%%x.pwn
   start ../pawno/pawncc.exe tbotfootsingle%%x.pwn
)