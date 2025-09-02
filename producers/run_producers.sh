 source infra/.out.env
 cd producers
 TOPIC=auth_txn 
 EH_BROKER=$EH_BROKER 
 EH_SEND="$EH_SEND" 
 python3 send_auth_txn.py
 &
 TOPIC=insider_events 
 EH_BROKER=$EH_BROKER 
 EH_SEND="$EH_SEND" 
 python3 send_insider.py