netsh rpc filter

:: MS-RPRN — Print Spooler UUID 1 (PrinterBug)
add rule layer=um actiontype=block
add condition field=if_uuid matchtype=equal data=12345678-1234-ABCD-EF00-0123456789AB
add filter

:: MS-RPRN — Print Spooler UUID 2 (PrinterBug)
add rule layer=um actiontype=block
add condition field=if_uuid matchtype=equal data=c681d488-d850-11d0-8c52-00c04fd90f7e
add filter

:: MS-PAR — Print System Async (AsyncPrintBug)
add rule layer=um actiontype=block
add condition field=if_uuid matchtype=equal data=76f03f96-cdfd-44fc-a22c-64950a001209
add filter

:: MS-EFSR — EFS RPC UUID 1 (PetitPotam)
add rule layer=um actiontype=block
add condition field=if_uuid matchtype=equal data=df1941c5-fe89-4e79-bf10-463657acf44d
add filter

:: MS-EFSR — EFS RPC UUID 2 (PetitPotam)
add rule layer=um actiontype=block
add condition field=if_uuid matchtype=equal data=c8cb7687-e6d3-11d2-a958-00c04f682e16
add filter

:: MS-DFSNM — DFS Namespace (DFSCoerce)
add rule layer=um actiontype=block
add condition field=if_uuid matchtype=equal data=4fc742e0-4a10-11cf-8273-00aa004ae673
add filter

:: MS-FSRVP — File Server VSS Agent (ShadowCoerce)
add rule layer=um actiontype=block
add condition field=if_uuid matchtype=equal data=a8e0653c-2744-4389-a61d-7373df8b2292
add filter

:: MS-EVEN — EventLog (EventLog coercion)
add rule layer=um actiontype=block
add condition field=if_uuid matchtype=equal data=82273fdc-e32a-18c3-3f78-827929dc23ea
add filter

:: MS-EVEN6 — EventLog6 Vista+ (EventLog6 coercion)
add rule layer=um actiontype=block
add condition field=if_uuid matchtype=equal data=f6beaff7-1e19-4fbb-9f8f-b89e2018337c
add filter

quit
