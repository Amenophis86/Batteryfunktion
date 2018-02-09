#########################################################################
# Helper for readingsGroup BatteryStatus:
# reads the battery states of devices and
# calculates the battery state in percent (depending on device type) and
# stores it as reading in corresponding dummy device

sub BatteryStatusFunction($$)
{
  my ($Device, $Event)  = @_;
  my @BatteryType = split(/:/,$Event); # to distinguish between "battery" and "batteryLevel" devices
  my $Model = AttrVal($Device, "model", "undef"); # get the corresponding model type
  my $TYPE = InternalVal($Device, "TYPE", "undef"); # get the TYPE of the device
  my $ActBatLevel = 0.0;
  my $MinBatLevel = 0.0;
  my $RemainingVoltageQuater = 0.0; # for "calculating" the colors
  my $MaxBattery = 3.1; # two 1.5V batteries have a measured voltage of 3.1V or even 3.2V
  my @DeviceNameParts = split(/_/,$Device); # to filter out HM_ Devices from neighbor or test system or newly included ones
  my $SignalDevice = $Device . "_BatState";

###############################
# Here you can change the variables to fit your installation.
#
  my $text_now = "Die Batterien von $Device müssen JETZT gewechselt werden!"; #Text for changing battery now
  my $text_soon = "Die Batterien von $Device sollten bald gewechselt werden!"; #Text for changing battery soon
  my $text_motorErrValve = "Der Motor kann sich nicht mehr bewegen!"; #Text for motorErr ValveErrorPosition only HM
  my $text_changed = "Batterie zuletzt gewechselt: "; #Text for last change
  my $BatteryStatus = "BatterieStatus"; #Name of the Dummy for status
  my $BatteryChanged = "BatterieWechsel"; #Name of the Dummy for battery changed information
  
###############################
# Here you can change the times for the temp-at and waittime for the reduction of 5% steps
#  
  my $FivePercent_HM = 600;
  my $TempAt_HM = 43200;
  my $FivePercent_Max = 600;
  my $TempAt_Max = 43200;
  my $FivePercent_Xiaomi = 600;
  my $TempAt_Xiaomi = 43200;
  my $FivePercent_ZWave = 600;
  my $TempAt_ZWave = 600;
  my $FivePercent_LaCrosse = 600;
  my $TempAt_LaCrosse = 43200;
  my $FivePercent_Other = 600;
  my $TempAt_Other = 43200;
  

################################
# Here you choos your message device and how to send
# comment the device you do not want to use
#
# TelegramBot
  my $msg = "set TelegramBot message \@\@User ";
#
# msg-command
# my $msg = "msg \@User title='Battery Check' ";
#
# Pushover 
# my $msg = "set Pushover msg device=User title='Battery Check' ";


  
#  Log3(undef, 1, "my_StoreBatteryStatus      Device: $Device       Event: $Event      Model: $Model");
  
  # ignoring Devices that were just created by autocreate
  if($DeviceNameParts[0] eq "HM" || $DeviceNameParts[0] eq "ZWave" || $DeviceNameParts[0] eq "MAX" || $DeviceNameParts[0] eq "LaCrosse")
  {
    Log3(undef, 1, "my_StoreBatteryStatus      ignoring Device: $Device");
    return;
  }
    
  # actually only devices HM-TC-IT-WM-W-EU and HM-CC-RT-DN have battery level and min-level
  # so calculating the percentage of actual level depending on min-level
  # all others just have battery ok or nok
  # IMPORTANT: first filter those which only send "battery" in EVENT
  #            then calculate for those which send "batteryLevel"!
  #            New devices: ZWave. They deliver battery already in percentage.
  #            New devices: XiaomiFlowerSens. They also deliver batteryLevel but already in percentage.

  #############################################
  #############################################
  # Every device with battery reading
  #############################################
  #############################################
  if($BatteryType[0] eq "battery") 
  {
  
   ##############################################
   # HM Devices with battery
   ##############################################
   if($TYPE eq "CUL_HM" and ReadingsVal($Device, "batteryLevel", "undef") eq "undef")
   {
	my $level = ReadingsNum($BatteryStatus, $Device, 0);

    if($Event eq "battery: ok")
		{
		 # Log3(undef, 3,"$Device, Batt ok");
		  if (defined($defs{"at_BatLow_".$Device})) # temporary at allready defined?
		 {
		  CommandDelete(undef,"at_BatLow_".$Device)  if (defined($defs{"at_BatLow_".$Device})); #if defined delete it, battery not dead yet or allready changed?
		  Log3(undef, 3,"$Device, deleted at_BatLow_".$Device);
		 }
		  if(ReadingsVal($BatteryStatus, $Device, undef) eq undef) # set battery level 100% and show in BatteryStatus-Device if new
		 {
		  readingsSingleUpdate($defs{$BatteryStatus},$Device, 100,0); 
		  Log3(undef, 3, "$Device, added to $BatteryStatus");
		 }
		 return undef;
		}
     elsif ($Event eq "battery: low")
		{
		 Log3(undef, 3,"$Device, Batt low");
		 
		return undef  if (ReadingsAge($BatteryStatus, $Device,0) < $FivePercent_HM); #take some time since the last event
		 Log3(undef, 3,"$Device, Batt low2");
		  if($level == 100)
		  {
		   readingsSingleUpdate($defs{$BatteryStatus},$Device, 75,0); # set battery level 75%
		   return undef;
		  }
		  elsif ($level > 25)
		  {
			$level -=5;
			readingsSingleUpdate($defs{$BatteryStatus}, $Device, $level,0); # reduce battery level by 5 with every event
			Log3(undef, 3,"$Device, Batt Level $level");
			return undef;
		  } 
		   elsif ($level == 25)
		  {
			fhem($msg." ".$text_soon);

			my $time_s = strftime("\%H:\%M:\%S", gmtime($TempAt_HM));  # 12 hours waittime for the temp at  
			my $error = CommandDefine(undef, "at_BatLow_".$Device." at +".$time_s." {BatteryStatusFunction('".$Device."','battery: dead')}");
			if (!$error) { $attr{"at_BatLow_".$Device}{room} = AttrVal($BatteryStatus,"room","Unsorted"); }
			else { Log3(undef, 3,"$Device, temp at error -> $error"); }
			
			$level -=5;
			readingsSingleUpdate($defs{$BatteryStatus}, $Device, $level,0); # reduce battery level by 5 with every event
			Log3(undef, 3,"$Device, Batt Level $level");
			
			return undef; 
		  }
		   elsif ($level < 25 && $level >= 10)
		  {
		    $level -=5;
			readingsSingleUpdate($defs{$BatteryStatus}, $Device, $level,0); # reduce battery level by 5 with every event
			Log3(undef, 3,"$Device, Batt Level $level");
			
			return undef; 
		  }
		   elsif($level == 5)
		  {
		    return undef;
		  }
		   else { Log3(undef, 3,"$Device, unknown Level $level") if ($level);}
		}
     elsif ($Event eq "battery: dead")
		{
		 Log3(undef, 3,"$Device, dead Event !");
		 readingsSingleUpdate($defs{$BatteryStatus},$Device,0,1); # set device 0 with an event 
		 fhem($msg." ".$text_now);
		 return undef;
		}
     else
		{
		 Log3(undef, 3,"$Device, unknown Event $Event");
		}
	}
   
   
   ##############################################
   # ZWave Devices with battery
   ##############################################
   elsif($TYPE eq "ZWave" and (ReadingsVal($Device, "battery", "undef") eq "ok" || ReadingsVal($Device, "battery", "undef") eq "low" )) #Z-Wave with batteryLevel sets the level in the reading battery
	{	
	my $level = ReadingsNum($BatteryStatus, $Device, 0);

    if($Event eq "battery: ok")
		{
		 # Log3(undef, 3,"$Device, Batt ok");
		  if (defined($defs{"at_BatLow_".$Device})) # temporary at allready defined?
		 {
		  CommandDelete(undef,"at_BatLow_".$Device)  if (defined($defs{"at_BatLow_".$Device})); #if defined delete it, battery not dead yet or allready changed?
		  Log3(undef, 3,"$Device, deleted at_BatLow_".$Device);
		 }
		  if(ReadingsVal($BatteryStatus, $Device, undef) eq undef) # set battery level 100% and show in BatteryStatus-Device if new
		 {
		  readingsSingleUpdate($defs{$BatteryStatus},$Device, 100,0); 
		  Log3(undef, 3, "$Device, added to $BatteryStatus");
		 }
		 return undef;
		}
     elsif ($Event eq "battery: low")
		{
		 Log3(undef, 3,"$Device, Batt low");
		 
		return undef  if (ReadingsAge($BatteryStatus, $Device,0) < $FivePercent_ZWave); #take some time since the last event
		 Log3(undef, 3,"$Device, Batt low2");
		  if($level == 100)
		  {
		   readingsSingleUpdate($defs{$BatteryStatus},$Device, 75,0); # set battery level 75%
		   return undef;
		  }
		  elsif ($level > 25)
		  {
			$level -=5;
			readingsSingleUpdate($defs{$BatteryStatus}, $Device, $level,0); # reduce battery level by 5 with every event
			Log3(undef, 3,"$Device, Batt Level $level");
			return undef;
		  } 
		   elsif ($level == 25)
		  {
			fhem($msg." ".$text_soon);

			my $time_s = strftime("\%H:\%M:\%S", gmtime($TempAt_ZWave));  # 12 hours waittime for the temp at  
			my $error = CommandDefine(undef, "at_BatLow_".$Device." at +".$time_s." {BatteryStatusFunction('".$Device."','battery: dead')}");
			if (!$error) { $attr{"at_BatLow_".$Device}{room} = AttrVal($BatteryStatus,"room","Unsorted"); }
			else { Log3(undef, 3,"$Device, temp at error -> $error"); }
			
			$level -=5;
			readingsSingleUpdate($defs{$BatteryStatus}, $Device, $level,0); # reduce battery level by 5 with every event
			Log3(undef, 3,"$Device, Batt Level $level");
			
			return undef; 
		  }
		   elsif ($level < 25 && $level >= 10)
		  {
		    $level -=5;
			readingsSingleUpdate($defs{$BatteryStatus}, $Device, $level,0); # reduce battery level by 5 with every event
			Log3(undef, 3,"$Device, Batt Level $level");
			
			return undef;		   
		  }
		   elsif($level == 5)
		  {
		    return undef;
		  }
		   else { Log3(undef, 3,"$Device, unknown Level $level") if ($level);}
		}
     elsif ($Event eq "battery: dead")
		{
		 Log3(undef, 3,"$Device, dead Event !");
		 readingsSingleUpdate($defs{$BatteryStatus},$Device,0,1); # set device 0 with an event 
		 fhem($msg." ".$text_now);
		 return undef;
		}
     else
		{
		 Log3(undef, 3,"$Device, unknown Event $Event");
		}
	}
   
   ##############################################
   # Xiaomi Devices with battery
   ##############################################
   elsif($TYPE =~ "Xiaomi" and ReadingsVal($Device, "batteryLevel", "undef") eq "undef")
	{
	my $level = ReadingsNum($BatteryStatus, $Device, 0);

    if($Event eq "battery: ok")
		{
		 # Log3(undef, 3,"$Device, Batt ok");
		  if (defined($defs{"at_BatLow_".$Device})) # temporary at allready defined?
		 {
		  CommandDelete(undef,"at_BatLow_".$Device)  if (defined($defs{"at_BatLow_".$Device})); #if defined delete it, battery not dead yet or allready changed?
		  Log3(undef, 3,"$Device, deleted at_BatLow_".$Device);
		 }
		  if(ReadingsVal($BatteryStatus, $Device, undef) eq undef) # set battery level 100% and show in BatteryStatus-Device if new
		 {
		  readingsSingleUpdate($defs{$BatteryStatus},$Device, 100,0); 
		  Log3(undef, 3, "$Device, added to $BatteryStatus");
		 }
		 return undef;
		}
     elsif ($Event eq "battery: low")
		{
		 Log3(undef, 3,"$Device, Batt low");
		 
		return undef  if (ReadingsAge($BatteryStatus, $Device,0) < $FivePercent_Xiaomi); #take some time since the last event
		 Log3(undef, 3,"$Device, Batt low2");
		  if($level == 100)
		  {
		   readingsSingleUpdate($defs{$BatteryStatus},$Device, 75,0); # set battery level 75%
		   return undef;
		  }
		  elsif ($level > 25)
		  {
			$level -=5;
			readingsSingleUpdate($defs{$BatteryStatus}, $Device, $level,0); # reduce battery level by 5 with every event
			Log3(undef, 3,"$Device, Batt Level $level");
			return undef;
		  } 
		   elsif ($level == 25)
		  {
			fhem($msg." ".$text_soon);

			my $time_s = strftime("\%H:\%M:\%S", gmtime($TempAt_Xiaomi));  # 12 hours waittime for the temp at  
			my $error = CommandDefine(undef, "at_BatLow_".$Device." at +".$time_s." {BatteryStatusFunction('".$Device."','battery: dead')}");
			if (!$error) { $attr{"at_BatLow_".$Device}{room} = AttrVal($BatteryStatus,"room","Unsorted"); }
			else { Log3(undef, 3,"$Device, temp at error -> $error"); }
			
			$level -=5;
			readingsSingleUpdate($defs{$BatteryStatus}, $Device, $level,0); # reduce battery level by 5 with every event
			Log3(undef, 3,"$Device, Batt Level $level");
			
			return undef; 
		  }
		   elsif ($level < 25 && $level >= 10)
		  {
		    $level -=5;
			readingsSingleUpdate($defs{$BatteryStatus}, $Device, $level,0); # reduce battery level by 5 with every event
			Log3(undef, 3,"$Device, Batt Level $level");
			
			return undef;
		  }
		   elsif($level == 5)
		  {
		    return undef;
		  }
		   else { Log3(undef, 3,"$Device, unknown Level $level") if ($level);}
		}
     elsif ($Event eq "battery: dead")
		{
		 Log3(undef, 3,"$Device, dead Event !");
		 readingsSingleUpdate($defs{$BatteryStatus},$Device,0,1); # set device 0 with an event 
		 fhem($msg." ".$text_now);
		 return undef;
		}
     else
		{
		 Log3(undef, 3,"$Device, unknown Event $Event");
		}
	}
   
   ##############################################
   # MAX! Devices with battery
   ##############################################
   elsif($TYPE eq "MAX" and ReadingsVal($Device, "batteryLevel", "undef") eq "undef")
   {
	my $level = ReadingsNum($BatteryStatus, $Device, 0);

    if($Event eq "battery: ok")
		{
		 # Log3(undef, 3,"$Device, Batt ok");
		  if (defined($defs{"at_BatLow_".$Device})) # temporary at allready defined?
		 {
		  CommandDelete(undef,"at_BatLow_".$Device)  if (defined($defs{"at_BatLow_".$Device})); #if defined delete it, battery not dead yet or allready changed?
		  Log3(undef, 3,"$Device, deleted at_BatLow_".$Device);
		 }
		  if(ReadingsVal($BatteryStatus, $Device, undef) eq undef) # set battery level 100% and show in BatteryStatus-Device if new
		 {
		  readingsSingleUpdate($defs{$BatteryStatus},$Device, 100,0); 
		  Log3(undef, 3, "$Device, added to $BatteryStatus");
		 }
		 return undef;
		}
     elsif ($Event eq "battery: low")
		{
		 Log3(undef, 3,"$Device, Batt low");
		 
		return undef  if (ReadingsAge($BatteryStatus, $Device,0) < $FivePercent_Max); #take some time since the last event
		 Log3(undef, 3,"$Device, Batt low2");
		  if($level == 100)
		  {
		   readingsSingleUpdate($defs{$BatteryStatus},$Device, 75,0); # set battery level 75%
		   return undef;
		  }
		  elsif ($level > 25)
		  {
			$level -=5;
			readingsSingleUpdate($defs{$BatteryStatus}, $Device, $level,0); # reduce battery level by 5 with every event
			Log3(undef, 3,"$Device, Batt Level $level");
			return undef;
		  } 
		   elsif ($level == 25)
		  {
			fhem($msg." ".$text_soon);

			my $time_s = strftime("\%H:\%M:\%S", gmtime($TempAt_Max));  # 12 hours waittime for the temp at  
			my $error = CommandDefine(undef, "at_BatLow_".$Device." at +".$time_s." {BatteryStatusFunction('".$Device."','battery: dead')}");
			if (!$error) { $attr{"at_BatLow_".$Device}{room} = AttrVal($BatteryStatus,"room","Unsorted"); }
			else { Log3(undef, 3,"$Device, temp at error -> $error"); }
			
			$level -=5;
			readingsSingleUpdate($defs{$BatteryStatus}, $Device, $level,0); # reduce battery level by 5 with every event
			Log3(undef, 3,"$Device, Batt Level $level");
			
			return undef; 
		  }
		   elsif ($level < 25 && $level >= 10)
		  {
		    $level -=5;
			readingsSingleUpdate($defs{$BatteryStatus}, $Device, $level,0); # reduce battery level by 5 with every event
			Log3(undef, 3,"$Device, Batt Level $level");
			
			return undef;
		  }
		   elsif($level == 5)
		  {
		    return undef;
		  }
		   else { Log3(undef, 3,"$Device, unknown Level $level") if ($level);}
		}
     elsif ($Event eq "battery: dead")
		{
		 Log3(undef, 3,"$Device, dead Event !");
		 readingsSingleUpdate($defs{$BatteryStatus},$Device,0,1); # set device 0 with an event 
		 fhem($msg." ".$text_now);
		 return undef;
		}
     else
		{
		 Log3(undef, 3,"$Device, unknown Event $Event");
		}
   }
   
   ##############################################
   # LaCrosse Devices with battery
   ##############################################
   elsif($TYPE eq "LaCrosse" and ReadingsVal($Device, "batteryLevel", "undef") eq "undef")
	{
	my $level = ReadingsNum($BatteryStatus, $Device, 0);

    if($Event eq "battery: ok")
		{
		 # Log3(undef, 3,"$Device, Batt ok");
		  if (defined($defs{"at_BatLow_".$Device})) # temporary at allready defined?
		 {
		  CommandDelete(undef,"at_BatLow_".$Device)  if (defined($defs{"at_BatLow_".$Device})); #if defined delete it, battery not dead yet or allready changed?
		  Log3(undef, 3,"$Device, deleted at_BatLow_".$Device);
		 }
		  if(ReadingsVal($BatteryStatus, $Device, undef) eq undef) # set battery level 100% and show in BatteryStatus-Device if new
		 {
		  readingsSingleUpdate($defs{$BatteryStatus},$Device, 100,0); 
		  Log3(undef, 3, "$Device, added to $BatteryStatus");
		 }
		 return undef;
		}
     elsif ($Event eq "battery: low")
		{
		 Log3(undef, 3,"$Device, Batt low");
		 
		return undef  if (ReadingsAge($BatteryStatus, $Device,0) < $FivePercent_LaCrosse); #take some time since the last event
		 Log3(undef, 3,"$Device, Batt low2");
		  if($level == 100)
		  {
		   readingsSingleUpdate($defs{$BatteryStatus},$Device, 75,0); # set battery level 75%
		   return undef;
		  }
		  elsif ($level > 25)
		  {
			$level -=5;
			readingsSingleUpdate($defs{$BatteryStatus}, $Device, $level,0); # reduce battery level by 5 with every event
			Log3(undef, 3,"$Device, Batt Level $level");
			return undef;
		  } 
		   elsif ($level == 25)
		  {
			fhem($msg." ".$text_soon);

			my $time_s = strftime("\%H:\%M:\%S", gmtime($TempAt_LaCrosse));  # 12 hours waittime for the temp at  
			my $error = CommandDefine(undef, "at_BatLow_".$Device." at +".$time_s." {BatteryStatusFunction('".$Device."','battery: dead')}");
			if (!$error) { $attr{"at_BatLow_".$Device}{room} = AttrVal($BatteryStatus,"room","Unsorted"); }
			else { Log3(undef, 3,"$Device, temp at error -> $error"); }
			
			$level -=5;
			readingsSingleUpdate($defs{$BatteryStatus}, $Device, $level,0); # reduce battery level by 5 with every event
			Log3(undef, 3,"$Device, Batt Level $level");
			
			return undef; 
		  }
		   elsif ($level < 25 && $level >= 10)
		  {
		    $level -=5;
			readingsSingleUpdate($defs{$BatteryStatus}, $Device, $level,0); # reduce battery level by 5 with every event
			Log3(undef, 3,"$Device, Batt Level $level");
			
			return undef;
		  }
		   elsif($level == 5)
		  {
		    return undef;
		  }		  
		   else { Log3(undef, 3,"$Device, unknown Level $level") if ($level);}
		}
     elsif ($Event eq "battery: dead")
		{
		 Log3(undef, 3,"$Device, dead Event !");
		 readingsSingleUpdate($defs{$BatteryStatus},$Device,0,1); # set device 0 with an event 
		 fhem($msg." ".$text_now);
		 return undef;
		}
     else
		{
		 Log3(undef, 3,"$Device, unknown Event $Event");
		}
	}
   
   ##############################################
   # All other Devices with battery
   ##############################################
   elsif (ReadingsVal($Device, "batteryLevel", "undef") eq "undef" and $TYPE ne "ZWave")
	{
	my $level = ReadingsNum($BatteryStatus, $Device, 0);

    if($Event eq "battery: ok")
		{
		 # Log3(undef, 3,"$Device, Batt ok");
		  if (defined($defs{"at_BatLow_".$Device})) # temporary at allready defined?
		 {
		  CommandDelete(undef,"at_BatLow_".$Device)  if (defined($defs{"at_BatLow_".$Device})); #if defined delete it, battery not dead yet or allready changed?
		  Log3(undef, 3,"$Device, deleted at_BatLow_".$Device);
		 }
		  if(ReadingsVal($BatteryStatus, $Device, undef) eq undef) # set battery level 100% and show in BatteryStatus-Device if new
		 {
		  readingsSingleUpdate($defs{$BatteryStatus},$Device, 100,0); 
		  Log3(undef, 3, "$Device, added to $BatteryStatus");
		 }
		 return undef;
		}
     elsif ($Event eq "battery: low")
		{
		 Log3(undef, 3,"$Device, Batt low");
		 
		return undef  if (ReadingsAge($BatteryStatus, $Device,0) < $FivePercent_Other); #take some time since the last event
		 Log3(undef, 3,"$Device, Batt low2");
		  if($level == 100)
		  {
		   readingsSingleUpdate($defs{$BatteryStatus},$Device, 75,0); # set battery level 75%
		   return undef;
		  }
		  elsif ($level > 25)
		  {
			$level -=5;
			readingsSingleUpdate($defs{$BatteryStatus}, $Device, $level,0); # reduce battery level by 5 with every event
			Log3(undef, 3,"$Device, Batt Level $level");
			return undef;
		  } 
		   elsif ($level == 25)
		  {
			fhem($msg." ".$text_soon);

			my $time_s = strftime("\%H:\%M:\%S", gmtime($TempAt_Other));  # 12 hours waittime for the temp at  
			my $error = CommandDefine(undef, "at_BatLow_".$Device." at +".$time_s." {BatteryStatusFunction('".$Device."','battery: dead')}");
			if (!$error) { $attr{"at_BatLow_".$Device}{room} = AttrVal($BatteryStatus,"room","Unsorted"); }
			else { Log3(undef, 3,"$Device, temp at error -> $error"); }
			
			$level -=5;
			readingsSingleUpdate($defs{$BatteryStatus}, $Device, $level,0); # reduce battery level by 5 with every event
			Log3(undef, 3,"$Device, Batt Level $level");
			
			return undef; 
		  }
		   elsif ($level < 25 && $level >= 10)
		  {
		    $level -=5;
			readingsSingleUpdate($defs{$BatteryStatus}, $Device, $level,0); # reduce battery level by 5 with every event
			Log3(undef, 3,"$Device, Batt Level $level");
			
			return undef;
		  }
		   elsif($level == 5)
		  {
		    return undef;
		  }
		   else { Log3(undef, 3,"$Device, unknown Level $level") if ($level);}
		}
     elsif ($Event eq "battery: dead")
		{
		 Log3(undef, 3,"$Device, dead Event !");
		 readingsSingleUpdate($defs{$BatteryStatus},$Device,0,1); # set device 0 with an event 
		 fhem($msg." ".$text_now);
		 return undef;
		}
     else
		{
		 Log3(undef, 3,"$Device, unknown Event $Event");
		}
	}
  
  }
  
  #############################################
  #############################################
  # Every device with batteryLevel reading
  #############################################
  #############################################
  elsif($BatteryType[0] eq "batteryLevel")
  {
  
   ##############################################
   # HM Devices with batteryLevel
   ##############################################
   if($TYPE eq "CUL_HM")
   {
	$ActBatLevel = ReadingsVal($Device, "batteryLevel", "0.0");
	$MinBatLevel = ReadingsNum($Device, "R-lowBatLimitRT", "0.0");
	$RemainingVoltageQuater = ($MaxBattery - $MinBatLevel) / 4; # to get 4 quaters for different colours and icons

	if(($ActBatLevel - $MinBatLevel) > (3 * $RemainingVoltageQuater))
		{
		  # check if battery was low before -> possibly changed
		if(ReadingsVal($BatteryStatus, $Device, 100) < 25)
		  {
			# set date/time for changed battery if it was low before (so probably a change happended)
			readingsSingleUpdate($defs{$BatteryChanged}, $Device, $text_changed, 0);
		  }

		  # set battery value to 100%
		  readingsSingleUpdate($defs{$BatteryStatus}, $Device, 100, 0);
		  
		  return undef;
		}
	elsif(($ActBatLevel - $MinBatLevel) > (2 * $RemainingVoltageQuater))
		{
		  # between 50% and 75%
		  readingsSingleUpdate($defs{$BatteryStatus}, $Device, 75, 0);
		  
		  return undef;
		}
	elsif(($ActBatLevel - $MinBatLevel) > (1 * $RemainingVoltageQuater))
		{
		  # between 25% and 50%
		  readingsSingleUpdate($defs{$BatteryStatus}, $Device, 50, 0);
		  
		  return undef;
		}
	elsif(($ActBatLevel - $MinBatLevel) > (0 * $RemainingVoltageQuater))
		{
		  if(ReadingsVal($BatteryStatus, $Device, 0) != 25) # check befor action if already has the status
		    {
				# check for critical stuff
				if(ReadingsVal($Device, "motorErr", "ok") eq "lowBat" || ReadingsVal($Device, "motorErr", "ok") eq "ValveErrorPosition")
				  {
					
					if(ReadingsVal($Device, "motorErr", "ok") eq "ValveErrorPosition")
					  {
					    # empty!
						readingsSingleUpdate($defs{$BatteryStatus}, $Device, 0, 0);
						fhem($msg." ".$text_now." ".$text_motorErrValve);
						return undef;
					  }
					else
					  {
					    # between 0% and 25%
						readingsSingleUpdate($defs{$BatteryStatus}, $Device, 25, 0);
						fhem($msg." ".$text_soon);
						return undef;
					  }
				  }
			    else
				  {
					# between 0% and 25%
					readingsSingleUpdate($defs{$BatteryStatus}, $Device, 25, 0);
					return undef;
				  }
		   }
		}
	else
		{
		  if(ReadingsVal($BatteryStatus, $Device, 0) != 0) # check befor action if already has the status
		    {
			  # totally empty
			  readingsSingleUpdate($defs{$BatteryStatus}, $Device, 0, 0);

			  #send message
			  fhem($msg." ".$text_now);
			}
		}
    }
   }
   
   ##############################################
   # Z-Wave Devices with batteryLevel
   ##############################################
   if($TYPE eq "ZWave" and ReadingsVal($Device, "battery", undef) =~ "%")
   {
	Log 3, ReadingsVal($Device, "battery", undef);
	$ActBatLevel = ReadingsNum($Device, "battery", "0");
	
	if(ReadingsNum($BatteryStatus, $Device, undef) == undef) # set battery level 100% and show in BatteryStatus-Device if new
		 {
		  readingsSingleUpdate($defs{$BatteryStatus},$Device, $ActBatLevel,0); 
		  Log3(undef, 3, "$Device, added to $BatteryStatus");
		  return;
		 }

	if($ActBatLevel > 75)
		{
		  # check if battery was low before -> possibly changed
		if(ReadingsVal($BatteryStatus, $Device, 100) < 25)
		  {
			# set date/time for changed battery if it was low before (so probably a change happended)
			readingsSingleUpdate($defs{$BatteryChanged}, $Device, $text_changed, 0);
		  }

		  # set battery value to 100%
		  readingsSingleUpdate($defs{$BatteryStatus}, $Device, $ActBatLevel, 0);
		  
		  return undef;
		}
	elsif($ActBatLevel > 50)
		{
		  # between 50% and 75%
		  readingsSingleUpdate($defs{$BatteryStatus}, $Device, $ActBatLevel, 0);
		  
		  return undef;
		}
	elsif($ActBatLevel > 25)
		{
		  # between 25% and 50%
		  readingsSingleUpdate($defs{$BatteryStatus}, $Device, $ActBatLevel, 0);
		  
		  return undef;
		}
	elsif($ActBatLevel > 0)
		{
		  if(ReadingsVal($BatteryStatus, $Device, 0) != 25) # check befor action if already has the status
		    {
			fhem($msg." ".$text_soon);
			
			$ActBatLevel -= 1 if($ActBatLevel == 25); # reduce by one if level is 25 so the message is not send again
			
			# between 0% and 25%
			readingsSingleUpdate($defs{$BatteryStatus}, $Device, $ActBatLevel, 0);
			
			return undef;
			}
		}
	else
		{
		  if(ReadingsVal($BatteryStatus, $Device, 0) != 0) # check befor action if already has the status
		    {
			  # totally empty
			  readingsSingleUpdate($defs{$BatteryStatus}, $Device, 0, 0);

			  #send message
			  fhem($msg." ".$text_now);
			}
		}
    }
   
   
   ##############################################
   # Xiaomi Devices with batteryLevel
   ##############################################
   elsif($TYPE =~ "Xiaomi")
   {
    $ActBatLevel = ReadingsNum($Device, "batteryLevel", "0");

	if($ActBatLevel > 75)
	   {
		 # set date/time for changed battery if it was low before (so probably a change happended)
		if(ReadingsVal($BatteryStatus, $Device, 100) < 25)
		  {
			readingsSingleUpdate($defs{$BatteryChanged}, $Device, $text_changed, 0);
		  }

		  # set the battery value to 75% - 100%
		  readingsSingleUpdate($defs{$BatteryStatus}, $Device, 100, 0);
		  
		  return undef;
		}
	elsif($ActBatLevel > 50)
		{
		  # between 50% and 75%
		  readingsSingleUpdate($defs{$BatteryStatus}, $Device, 75, 0);
		  
		  return undef;
		}
	elsif($ActBatLevel > 25)
		{
		  # between 25% and 50%
		  readingsSingleUpdate($defs{$BatteryStatus}, $Device, 50, 0);
		  
		  return undef;
		}
	elsif($ActBatLevel > 5)
		{
		  if(ReadingsVal($BatteryStatus, $Device, 0) != 25) # check befor action if already has the status
		    {
			  # between 5% and 25%
			  readingsSingleUpdate($defs{$BatteryStatus}, $Device, 25, 0);
			  
			  fhem($msg." ".$text_soon);
			  return undef;
			}
		  
		  return undef;
		}
	else
		{
		  if(ReadingsVal($BatteryStatus, $Device, 0) != 0) # check befor action if already has the status
		    {
			  # totally empty (below 5%)
			  readingsSingleUpdate($defs{$BatteryStatus}, $Device, 0, 0);
			  		  
			  fhem($msg." ".$text_now);
			  return undef;
			}
		  
		  return undef;
		}
   }
   
   ##############################################
   # All other Devices with batteryLevel
   ##############################################
   else
   {
    $ActBatLevel = ReadingsNum($Device, "batteryLevel", "0");

	if($ActBatLevel > 75)
	   {
		 # set date/time for changed battery if it was low before (so probably a change happended)
		if(ReadingsVal($BatteryStatus, $Device, 100) < 25)
		  {
			readingsSingleUpdate($defs{$BatteryChanged}, $Device, $text_changed, 0);
		  }

		  # set the battery value to 75% - 100%
		  readingsSingleUpdate($defs{$BatteryStatus}, $Device, 100, 0);
		  
		  return undef;
		}
	elsif($ActBatLevel > 50)
		{
		  # between 50% and 75%
		  readingsSingleUpdate($defs{$BatteryStatus}, $Device, 75, 0);
		  
		  return undef;
		}
	elsif($ActBatLevel > 25)
		{
		  # between 25% and 50%
		  readingsSingleUpdate($defs{$BatteryStatus}, $Device, 50, 0);
		  
		  return undef;
		}
	elsif($ActBatLevel > 5)
		{
		  if(ReadingsVal($BatteryStatus, $Device, 0) != 25) # check befor action if already has the status
		    {
			  # between 5% and 25%
			  readingsSingleUpdate($defs{$BatteryStatus}, $Device, 25, 0);
			  
			  fhem($msg." ".$text_soon);
			  return undef;
			}
		  
		  return undef;
		}
	else
		{
		  if(ReadingsVal($BatteryStatus, $Device, 0) != 0) # check befor action if already has the status
		    {
			  # totally empty (below 5%)
			  readingsSingleUpdate($defs{$BatteryStatus}, $Device, 0, 0);
			  		  
			  fhem($msg." ".$text_now);
			  return undef;
			}
		  
		  return undef;
		}
  }

}

##################################################
# Helper for readingsGroup BatteryStatus:
# sets the icon and icon color depending on "calculated" percentage value
sub SetBatterieIcon($$)
{
  my ($Device, $Value)  = @_;
  my $Icon = "measure_battery_"; # here the matching icon is "set"
  my $ActionDetectorDevice = "status_" . $Device;
  my $Name = ""; # name for signal state
  my $State = ReadingsVal("ActionDetector", $ActionDetectorDevice, "alive");

#  Log3(undef, 1, "my_SetBatteryIcon      Device: $Device       Value: $Value");

  if($State ne "alive")
  {
    $Icon = "message_attention\@red";
  }
  else
  {
    if($Value > 75)
    {
      $Icon = $Icon . "100" . "\@green"; # between 75% and 100%
    }
     elsif($Value > 50)
    {
      $Icon = $Icon . "75" . "\@green"; # between 25% and 75%
    }
    elsif($Value > 25)
    {
      $Icon = $Icon . "50" . "\@yellow"; # between 25% and 75%
    }
	elsif($Value > 10)
    {
      $Icon = $Icon . "25" . "\@orange"; # between 25% and 75%
    }
    else
    {
      $Icon = $Icon . "0" . "\@red"; # below 25%
    }
  }

  return $Icon;
}

#####################################################
# Start script once and delet after

sub BatteryStart()
{
 #Define Dummys for script
 my $BatteryStatus = "BatterieStatus"; #Name of the Dummy for status
 my $BatteryChanged = "BatterieWechsel"; #Name of the Dummy for battery changed information
 my $ReadingsGroup = "rgBatteryStatus"; #Name of the ReadingsGroup
 my $Room = "Z_System->BatteryCheck"; #room for the dummys
 my $Notify = "NO.BatterieNotify"; #Name of the Notify for sending battery information
 
 fhem("setdefaultattr room $Room; define $BatteryStatus dummy; define $BatteryChanged dummy; 
      define $ReadingsGroup readingsGroup NAME=BatterieStatus:.*; attr $ReadingsGroup valueIcon {SetBatterieIcon(\$READING, \$VALUE)};
      attr $ReadingsGroup mapping \$READING; setdefaultattr;");
 
 
 #Set Readings for device with reading battery
 my @bat_b = devspec2array("battery=.*");
 for(my $x=0;$x<@bat_b;$x++)
 {
 	my $stat_b = ReadingsVal($bat_b[$x],"battery","undef");
 	if($stat_b ne "undef") 
	{
	 BatteryStatusFunction($bat_b[$x],"battery: $stat_b");
	}
 }
 
 #Set Readings for device with reading batteryLevel
 my @bat_l = devspec2array("batteryLevel=.*");
 for(my $x=0;$x<@bat_l;$x++)
 {
	my $stat_l = ReadingsVal($bat_l[$x],"batteryLevel","undef");
	if($stat_l ne "undef") 
	{
	 BatteryStatusFunction($bat_l[$x],"batteryLevel: $stat_l");
	}
 }
 
 fhem("define $Notify notify .*:battery.* {BatteryStatusFunction(\$NAME, \$EVENT)}; attr $Notify room $Room;")
}

