param([string]$Arguments)

$ScomAPI = New-Object -comObject "MOM.ScriptAPI"
$PropertyBag = $ScomAPI.CreatePropertyBag()



$process = Get-Process rhs

foreach($proc in $process) {
    
    If ($proc.ws -gt 5GB) 
        {
         $State = "OverThreshold"
         break
         
        }
    Else
        {

         $State = "UnderThreshold"

        }   
     
}

#Convert Memory useage to GB 

$RawMemory = ($proc.ws/1GB)
$Memory = [Math]::Round($Rawmemory,2)

# Add prooperties for Alert Description

$PropertyBag.AddValue("Memory",$Memory)
 

# State value for Monitor

$PropertyBag.AddValue("State",$State)


# Send output to SCOM

$PropertyBag
 

