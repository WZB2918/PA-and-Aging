/*import DEMO_C and paxraw_c*/
%include "D:/Homework/sleepanddiet/NHANESdata/0306/PA/PAM_formats.sas";
/*create.pam_perminute.sas  This program edits invalid and unreliable intensity values in the PAM data.*/
data paxraw;
set work.paxraw_c;
day=ceil(paxn/1440);
label day='Sequential Day';
format paxday wkday.;
run;
/*! counts that are not = 32767;*/
data invalid valid;
set paxraw;
by seqn;
if first.seqn then invalid_cnt=0;
retain invalid_cnt;
if paxinten=32767 then invalid_cnt=invalid_cnt+1;
if last.seqn then do;
if 0<invalid_cnt<6 then output invalid;
else output valid;
end;
run;
data paxraw_invalid;
merge invalid(in=in_invalid) paxraw;
by seqn;
if in_invalid;
run;
proc sort data=paxraw_invalid;
by seqn day paxn;
run;
data paxraw_new(keep=seqn day paxinten paxn);
set paxraw_invalid;
by seqn day paxn;
retain paxn_invalid
       paxn_valid
       last_int;
if paxinten = 32767 and paxn_invalid=. and not last.day then
paxn_invalid=paxn;
else if paxinten > . and paxinten ne 32767 then do;
if paxn_invalid ne . then do;
sv_int=paxinten;
sv_paxn=paxn;
do i=paxn_valid+1 to paxn-1;
paxn=i;
paxinten=round(sum(sv_int,last_int)/2);
output;
end;
paxn_invalid=.;
last_int=sv_int;
paxn_valid=sv_paxn;
end;
else do;
paxn_valid=paxn;
last_int=paxinten;
end;
end;
else if paxinten=32767 and last.day then do;
paxinten=last_int;
if paxn_invalid ne . then do;
do i=paxn_invalid to paxn;
paxn=i;
output;
end;
end;
else output;
end;
run;
proc sort data=paxraw_new;
by seqn day paxn ;
run;
proc sort data=paxraw;
by seqn day paxn ;
run;
 data pam_perminute;
update  paxraw paxraw_new;
by seqn day paxn ;
if PAXSTAT=2 then paxinten=.;
run;
data work.pam_perminute;
set pam_perminute;
run;
proc contents data=work.pam_perminute;
run;
/*create.pam_perday.sas This program summarizes valid PAM data into a dataset with one record per person per day. The summary record contains derived variables on duration of non-wear periods as well as activity bouts with moderate, vigorous, and moderate or vigorous intensity. The output dataset can be used for analysis at the day level, and it is an intermediate step for creating the pam_perperson dataset.*/
data monitor;
  merge work.pam_perminute(in=in_pam) work.demo_c(in=in_demog keep=seqn ridageyr);
  by seqn;
  if in_pam;
  if not in_demog then put 'ERROR! not in demog' seqn=;
  if paxcal=1;
run;
data monitors;
set monitor;
if RIDAGEYR<20 then delete;
run;
%macro nw(nwperiod=);
data nw_all;
  set monitors;
  by seqn day paxn;

  if first.day then nw_num=0;    /*non-wear period number*/

  if first.day or reset or stopped then do;
     strt_nw=0;      /*starting minute for the non-wear period*/
     end_nw=0;       /*ending minute for the non-wear period*/
     start=0;        /*indicator for starting to count the non-wear period*/
     dur_nw=0;       /*duration for the non-wear period*/
     reset=0;        /*indicator for resetting and starting over*/
     stopped=0;      /*indicator for stopping the non-wear period*/
     cnt_non_zero=0; /*counter for the number of minutes with intensity between 1 and 100*/
  end;
  retain nw_num strt_nw end_nw stopped reset start cnt_non_zero dur_nw;

  /*The non-wear period starts with a zero count*/
  if paxinten=0 and start=0 then do;
        strt_nw=paxn;    /*assign the starting minute of non-wear*/
        start=1;
  end;

  /*accumulate the number of the non-wear minutes*/
  if start and paxinten=0 then
     end_nw=paxn;         /*keep track of the ending minute for the non-wear period*/

  /*keep track of the number of minutes with intensity between 1-100*/
  if 0<paxinten<=100 then
     cnt_non_zero=cnt_non_zero+1;

  /*before reaching the 3 consecutive minutes of 1-100 intensity, if encounter one minute with zero intensity, reset the counter*/
  if paxinten=0 then cnt_non_zero=0;

  /*duration of non-wear period*/
  dur_nw=end_nw-strt_nw+1;

  /*A non-wear period ends with 3 consecutive minutes of 1-100 intensity, one missing count, or one minute with >100 intensity*/
  if (cnt_non_zero=3 or paxinten=. or paxinten>100 ) then do;
    if dur_nw<&nwperiod then reset=1;       /*reset if less than &nwperiod minutes of non-wear*/
    else stopped=1;
  end;

  /*last minute of the day*/
  if last.day and dur_nw>=&nwperiod then stopped=1;

  /*output one record for each non-wear period*/
  if stopped=1 then do;
       nw_num=nw_num+1;
       keep seqn day nw_num strt_nw end_nw dur_nw;
       output;
  end;
run;

*---------------------------------------------------------------------*;
*summarize the non-wear periods to one record per day                 *;
*---------------------------------------------------------------------*;
proc summary data=nw_all ;
  by seqn day;
  var dur_nw ;
  output out=sum_nw
       sum=tot_dur_nw
run;

*-------------------------------------------------------------------------*;
*summarize the total number of valid minutes for everyone in the analysis.*;
*-------------------------------------------------------------------------*;
proc summary data=monitors;
  by seqn day ridageyr paxday;
  var paxinten;
  output out=sum_all
         n=tot_min;
run;

*---------------------------------------------------------------------*;
*define hours of wear                                                 *;
*---------------------------------------------------------------------*;
/*create a dataset with one record per minute, for the non-wear periods only*/
data nw_minutes(keep=seqn day paxn);
  set nw_all;
  by seqn day nw_num;
  do i=strt_nw to end_nw by 1;
     paxn=i;
     output;
  end;
run;

/*create a dataset from the monitor data, restricted to the wear periods*/
data wear_minute(keep=seqn day paxn paxinten);
  merge monitors(in=in_all) nw_minutes(in=in_nw);
  by seqn day paxn;
  if in_all and not in_nw;
run;

/*summarize the wear minutes */
proc summary data=wear_minute;
  by seqn day;
  var paxinten;
  output out=sum_wear
         sum=tot_cnt_wr
         n=tot_min_wr;
run;

*---------------------------------------------------------------------*;
*final data for one record per day for everyone in the analysis.      *;
*---------------------------------------------------------------------*;
data nw&nwperiod;
  merge sum_all(in=in_all) sum_nw(in=in_nw) sum_wear;
  by seqn day;
  if in_all;

  if tot_dur_nw=. then tot_dur_nw=0;
  if tot_min_wr=. then tot_min_wr=0;
  if tot_cnt_wr=. then tot_cnt_wr=0;

  wear_hr=tot_min_wr/60;
  tot_dur_nw=tot_dur_nw/60;
  label
  tot_dur_nw='Total duration(hr) of non-wear periods in a day'
  wear_hr='Total number of wear hours for the day'
  tot_min='Total number of valid minutes within a day'
  tot_cnt_wr='Total intensity counts from all wear minutes in a day'
  tot_min_wr='Total number of wear minutes in a day'
  ;
  keep seqn paxday day ridageyr tot_min tot_min_wr wear_hr tot_cnt_wr tot_dur_nw;
run;

%mend nw;

%nw(nwperiod=60);
data monitors;
  set monitors;
  /*sedentary behaviors*/
  if ridageyr>=20 then sedthresh=100;

  /*ligorous threshold*/
  if ridageyr>=20 then ligthresh=500;

  /*moderate threshold*/
  if ridageyr>=20 then modthresh=2020;

  /*vigorous threshold*/
  if ridageyr>=20 then vigthresh=5999;

  /*sedentary behaviors*/
  if paxinten<sedthresh then _sed=1;
  else if paxinten ne . then _sed=0;
  
  /*inactive threshold*/
  if sedthresh<=paxinten<ligthresh then _ina=1;
  else if paxinten ne . then _ina=0;

  /*ligorous activity*/
  if ligthresh<=paxinten<modthresh then _lig=1;
  else if paxinten ne . then _lig=0;

  /*moderate activity*/
  if modthresh<=paxinten<vigthresh then _mod=1;
  else if paxinten ne . then _mod=0;

  /*vigorous activity*/
  if paxinten>=vigthresh then _vig=1;
  else if paxinten ne . then _vig=0;

run;
proc sort data=monitors; by seqn day paxn; run;
%macro bouts(bout_flg=,boutperiod=);
data out&bout_flg&boutperiod;
  set monitors;
  by seqn day paxn;
  if first.day then mv_num=0;       /*number of activity bouts*/

  if first.day or reset or stopped then do;
     strt_mv=0;     /*starting minute for the activity bout*/
     end_mv=0;      /*ending minute for the activity bout*/
     start=0;       /*indicator for starting the activity bout*/
     reset=0;       /*indicator for resetting and starting over*/
     mv_cnt=0;      /*number of minutes for the activity bout*/
     stopped=0;     /*indicator for stopping the activity bout*/
  end;
  retain mv_num strt_mv end_mv mv_cnt stopped reset start;


  /*start the bout when a count with intensity >= the threshold is encountered*/
  if &bout_flg=1 and start=0 then do;
        strt_mv=paxn;     /*assign the starting minute of the bout*/
        start=1;
  end;

  /*accumulate minutes with intensity counts >= the threshold*/
  if start=1 and &bout_flg=1 then do;
     mv_cnt=mv_cnt+1;
     end_mv=paxn;         /*keep track of the ending minute for the bout*/
  end;

  /*stop when encounter a minute with intensity < threshold or missing*/
  if &bout_flg in (0,.)  then  do;
     if mv_cnt<&boutperiod then reset=1;     /*reset if less than the bout length*/
     else stopped=1;
  end;

  /*last minute of the day*/
  if last.day and mv_cnt>=&boutperiod then stopped=1;

  /*output one record for each activity bout*/
  if stopped=1 then do;
      dur_mv=end_mv-strt_mv+1;
      mv_num=mv_num+1;
      output;
  label
  strt_mv='Starting minute for the activity bout'
  end_mv='Ending minute for the activity bout'
  dur_mv='Duration(minutes) of activity bout'
  mv_num='Number of activity bout'
  ;
  end;
  keep seqn  day mv_num strt_mv end_mv dur_mv ;
run;

proc sort data=out&bout_flg&boutperiod;
  by seqn day mv_num;
run;

*-----------------------------------------------*;
*calculate total duration of activity bouts for *;
*each day.                                      *;
*-----------------------------------------------*;
proc summary data=out&bout_flg&boutperiod;
  by seqn day;
  var dur_mv;
  output out=sum_mv
         sum=tot_dur_mv;
run;

*-----------------------------------------------*;
*output one record per day for each person in   *;
*the analysis.                                  *;
*-----------------------------------------------*;
data out&bout_flg&boutperiod._sum;
  merge sum_all(in=in_all) sum_mv;
  by seqn day;
  if in_all;
  if tot_dur_mv=. then tot_dur_mv=0;
  label
  %if &bout_flg=_sed %then %do;
    tot_dur_mv="Total duration(minutes) of sed bouts (minimum &boutperiod minute bouts) in a day"
  %end;
  %if &bout_flg=_ina %then %do;
    tot_dur_mv="Total duration(minutes) of ina bouts (minimum &boutperiod minute bouts) in a day"
  %end;
  %if &bout_flg=_lig %then %do;
    tot_dur_mv="Total duration(minutes) of lig bouts (minimum &boutperiod minute bouts) in a day"
  %end;
  %if &bout_flg=_mod %then %do;
    tot_dur_mv="Total duration(minutes) of mod bouts (minimum &boutperiod minute bouts) in a day"
  %end;
  %if &bout_flg=_vig %then %do;
    tot_dur_mv="Total duration(minutes) of vig bouts (minimum &boutperiod minute bouts) in a day"
  %end;
  ;
  keep seqn day tot_dur_mv;
  rename
  tot_dur_mv=tot_dur&bout_flg&boutperiod;
run;
%mend bouts;

*-----------------------------------------------*;
*create activity bouts with moderate, vigorous, *;
*and moderate or vigorous intensity.            *;
*-----------------------------------------------*;
%macro boutsgrp(boutperiod);
  %bouts(bout_flg=_sed,boutperiod=&boutperiod);
  %bouts(bout_flg=_ina,boutperiod=&boutperiod);
  %bouts(bout_flg=_lig,boutperiod=&boutperiod);
  %bouts(bout_flg=_mod,boutperiod=&boutperiod);
  %bouts(bout_flg=_vig,boutperiod=&boutperiod);
%mend boutsgrp;

*-----------------------------------------------*;
*set bout length here (now set to 1 min)        *;
*-----------------------------------------------*;
%boutsgrp(1); 
%macro bouts_8of10(bout_flg=);
data out&bout_flg;
  set monitors;
  by seqn day paxn;
  /*set up a 10 minute window*/
  array win_paxn(*) win_paxn1-win_paxn10;   /*minute*/
  array win_int(*) win_int1-win_int10;      /*intensity*/
  array win_flg(*) win_flg1-win_flg10;      /*bout flag*/

  if first.day then
     mv_num=0;             /*number of activity bouts*/

  if first.day or stopped or reset then do;
     strt_mv=0;     /*starting minute for the bout*/
     end_mv=0;      /*ending minute for the bout*/
     found=0;       /*set to 1 if a bout has been established*/
     reset=0;       /*reset the counts and start over*/
     stopped=0;     /*indicator for stopping the bout*/
     start=0;       /*start set to 1 if one above the threshold count is encountered*/
     mv_cnt=0;      /*number of minutes with counts >= the threshold*/
     sum10=.;       /*the total intensity counts from the 10 minute window*/
     cnt_below=0;   /*counter for number of minutes with intensity below the threshold*/ 
     do i=1 to 10;   /*initialize the 10 minute window*/
        win_paxn(i)=0;
        win_int(i)=0;
        win_flg(i)=0;
     end;
  end;
  retain mv_num reset strt_mv end_mv start mv_cnt  found stopped sum10 cnt_below;
  retain win_paxn1-win_paxn10;
  retain win_int1-win_int10;
  retain win_flg1-win_flg10;

  /*if the intensity count is >= the threshold, start the bout*/
  if &bout_flg=1 and start=0 then
     start=1;

  /*accumulate the counts*/
  if start=1 then mv_cnt=mv_cnt+1;

  /*set up a moving window of 10 minutes*/
  if 1<=mv_cnt<=10 and not found then do;
       win_paxn(mv_cnt)=paxn;
       win_int(mv_cnt)=paxinten;
       win_flg(mv_cnt)=&bout_flg;
       if paxinten = . then reset=1; /*if encounter a missing count before reaching the 10 minute count, reset and start again*/
   end;

   /*when reach 10 minutes, count the total number of intensity counts that are >= threshold*/
   if mv_cnt=10 and not reset then sum10=sum(of win_flg1-win_flg10);

   /*if 8 out of 10 minutes with intensity counts >= the threshold, a bout is established*/
   if sum10>=8 then found=1;

   /*if less than 8 minutes with intensity counts>= the threshold, continue to search*/
   /*move the 10-minute window down, one minute at a time*/ 
   else if 0<sum10<8 and mv_cnt>10 then do;
     if paxinten=. then reset=1;      /*if the 10th minute has a missing count, reset and start again*/
     else do;
          do i=1 to 9;
             win_paxn(i)=win_paxn(i+1);
             win_int(i)=win_int(i+1);
             win_flg(i)=win_flg(i+1);
          end;
          /*read in minute 10*/
          win_paxn(10)=paxn;
          win_int(10)=paxinten;
          win_flg(10)=&bout_flg;
          sum10=sum(of win_flg1-win_flg10);
     end;
   end;
   if sum10 in (0) then reset=1;               /*skip the windows with no valid minutes*/

  /*after the bout is established*/
  if found then do;
      /*assign the starting minute for the activity bout*/
      if strt_mv= 0 then do;
         do i=1 to 10;
            if win_flg(i)=1 then  do;  /*find the first minute with intensity count>=the threshold*/
               strt_mv=win_paxn(i);
               i=11;
            end;
         end;
      end;
      /*assign the ending minute for the activity bout*/
      if end_mv=0 then do;
         /*the last 2 minutes in the 10 minute window are below the threshold*/
         if win_flg(9)=0 and win_flg(10)=0 then do;
            end_mv= win_paxn(8);
            cnt_below=2;
         end;
         /*the last minute in the 10 minute window is below the threshold*/
         else if win_flg(10)=0 then do;
            end_mv=win_paxn(9);
            cnt_below=1;
         end;
         else
            end_mv=win_paxn(10);
      end;
      if paxn>win_paxn(10) then do;
         if &bout_flg=1 then do;
            cnt_below=0;
            end_mv=paxn;
         end;
         if &bout_flg=0  then
            cnt_below=cnt_below+1;  /*keep track of the number of minutes with intensity counts below the threshold*/
      end;
      /*bout terminates if 3 consecutive minutes below the threshold are encountered, or a missing count, or the last minute of the day*/
      if cnt_below=3 or last.day or &bout_flg=. then stopped=1;
  end;
  /*output one record for each activity bout*/
  if stopped=1 then do;
      dur_mv=end_mv-strt_mv+1;
      mv_num=mv_num+1;
      keep seqn day mv_num strt_mv end_mv dur_mv;
      output;
  end;
run;
proc sort data=out&bout_flg;
  by seqn day mv_num;
run;

*-----------------------------------------------*;
*calculate total duration of activity bouts for *;
*each day.                                      *;
*-----------------------------------------------*;
proc summary data=out&bout_flg;
  by seqn day;
  var dur_mv;
  output out=sum_mv
         sum=tot_dur_mv;
run;

*-----------------------------------------------*;
*output one record per day for each person in   *;
*the analysis.                                  *;
*-----------------------------------------------*;
data out&bout_flg._sum;
  merge sum_all(in=in_all) sum_mv;
  by seqn day;
  if in_all;
  if tot_dur_mv=. then tot_dur_mv=0;

  label
  %if &bout_flg=_sed %then %do;
    tot_dur_mv="Total duration(min) of sed activity bouts (8 out of 10 minutes) in a day"
  %end;
  %if &bout_flg=_ina %then %do;
    tot_dur_mv="Total duration(min) of ina activity bouts (8 out of 10 minutes) in a day"
  %end;
  %if &bout_flg=_lig %then %do;
    tot_dur_mv="Total duration(min) of lig activity bouts (8 out of 10 minutes) in a day"
  %end;
  %if &bout_flg=_mod %then %do;
    tot_dur_mv="Total duration(min) of mod activity bouts (8 out of 10 minutes) in a day"
  %end;
  %if &bout_flg=_vig %then %do;
    tot_dur_mv="Total duration(min) of vig activity bouts (8 out of 10 minutes) in a day"
  %end;
  ;

  keep seqn day tot_dur_mv;

  rename
  tot_dur_mv=tot_dur&bout_flg;
run;
%mend bouts_8of10;

%bouts_8of10(bout_flg=_sed);
%bouts_8of10(bout_flg=_ina);
%bouts_8of10(bout_flg=_lig);
%bouts_8of10(bout_flg=_mod);
%bouts_8of10(bout_flg=_vig);
data pam_perday;
  merge nw60
        out_sed_sum out_ina_sum out_lig_sum out_mod_sum out_vig_sum 
        out_sed1_sum out_ina1_sum out_lig1_sum out_mod1_sum out_vig1_sum  ;
  by seqn day;
run;
data work.pam_perday;
  set pam_perday;
run;
proc contents data=work.pam_perday;
run;
/*create.pam_perperson.sas This program summarizes valid PAM data into a dataset with one record per person and adds demographic variables. The output dataset can be used for analysis at the person level.*/
data pam_day;
  set work.pam_perday;
  valid_day=(wear_hr>=10); /*change valid day hours criterion here*/
  format valid_day yesno.;
  label valid_day='10+ hours of wear (yes/no)';
run;
proc summary data=pam_day;
  by seqn;
  var seqn;
  where valid_day=1;
  output out=valid
         n=valdays;     /*number of days with 10+ hours of wear*/
run;
data pam_day;
  merge pam_day(in=inall) valid;
  by seqn;
  if inall;

  if valdays=. then valdays=0;
  label valdays='Number of days with 10+ hours of wear';

  valid_person=(valdays>=1);  /*change valid person days criterion here*/
  format valid_person yesno.;
  label valid_person = 'At least 4 days with 10+ hours of wear (yes/no)';

  drop _freq_ _type_;

run;
proc summary data=pam_day;
  by seqn;
  where valid_person=1 and valid_day=1;
  var tot_dur_sed tot_dur_sed1
      tot_dur_ina tot_dur_ina1
      tot_dur_lig tot_dur_lig1
	  tot_dur_mod tot_dur_mod1
	  tot_dur_vig tot_dur_vig1
      tot_min_wr tot_cnt_wr;
  output out=valid_days
  mean(tot_dur_sed tot_dur_sed1
      tot_dur_ina tot_dur_ina1
      tot_dur_lig tot_dur_lig1
	  tot_dur_mod tot_dur_mod1
      tot_dur_vig tot_dur_vig1
      tot_min_wr)=
      allmean_sed allmean_sed1  /*mean duration of sed activity bouts*/
      allmean_ina allmean_ina1    /*mean duration of ina activity bouts*/
      allmean_lig allmean_lig1    /*mean duration of lig activity bouts*/
	  allmean_mod allmean_mod1  /*mean duration of mod activity bouts*/
      allmean_vig allmean_vig1    /*mean duration of vig activity bouts*/ 
      allmean_min_wr          /*mean wear time(minutes)*/
  sum(tot_min_wr tot_cnt_wr)=all_min_wr all_cnt_wr; /*total wear minutes and intensity counts*/
run;
data valid_days;
  set valid_days;
  allmean_cnt_wr=all_cnt_wr/all_min_wr; /*mean intensity counts per minute*/
  allmean_hr_wr=allmean_min_wr/60;      /*mean wear time(hr)*/
  label
  allmean_cnt_wr='Mean intensity count per minute on wear periods from all valid days'
  allmean_hr_wr='Mean wear time(hr) per day from all valid days'
  allmean_sed='Mean duration (minutes) of sed activity bouts (8 out of 10 minute bouts) per day from all valid days'
  allmean_ina='Mean duration (minutes) of ina activity bouts (8 out of 10 minute bouts) per day from all valid days'
  allmean_lig='Mean duration (minutes) of lig activity bouts (8 out of 10 minute bouts) per day from all valid days'
  allmean_mod='Mean duration (minutes) of mod activity bouts (8 out of 10 minute bouts) per day from all valid days'
  allmean_vig='Mean duration (minutes) of vig activity bouts (8 out of 10 minute bouts) per day from all valid days'
  allmean_sed1='Mean duration (minutes) of sed activity bouts (minimum 1 minute bouts) per day from all valid days'
  allmean_ina1='Mean duration (minutes) of ina activity bouts (minimum 1 minute bouts) per day from all valid days'
  allmean_lig1='Mean duration (minutes) of lig activity bouts (minimum 1 minute bouts) per day from all valid days'
  allmean_mod1='Mean duration (minutes) of mod activity bouts (minimum 1 minute bouts) per day from all valid days'
  allmean_vig1='Mean duration (minutes) of vig activity bouts (minimum 1 minute bouts) per day from all valid days';

  drop _type_  _freq_ allmean_min_wr;
run;
proc sort nodupkey data=pam_day out=pam_all;
  by seqn;
run;
data pam_perperson;
  merge pam_all(in=in_pam keep=seqn valid_person valdays) work.demo_c(in=in_demog) valid_days;* changed by kwd;
  by seqn;
  if in_pam;
  if not in_demog then put 'error: not in demog' seqn=;

  /*Age groups*/
  if       6<=ridageyr<=11 then agegrp=1;
  else if 12<=ridageyr<=15 then agegrp=2;
  else if 16<=ridageyr<=19 then agegrp=3;
  else if 20<=ridageyr<=29 then agegrp=4;
  else if 30<=ridageyr<=39 then agegrp=5;
  else if 40<=ridageyr<=49 then agegrp=6;
  else if 50<=ridageyr<=59 then agegrp=7;
  else if 60<=ridageyr<=69 then agegrp=8;
  else if ridageyr>=70     then agegrp=9;
  format agegrp agegrp.;
  label agegrp='Age group' ;

  /*Gender*/
  format riagendr gender.;
  label riagendr='Gender';

  keep seqn valid_person valdays riagendr agegrp ridageyr sdmvstra sdmvpsu wtmec2yr
       allmean_sed allmean_sed1 allmean_ina allmean_ina1 allmean_lig allmean_lig1 allmean_mod allmean_mod1 allmean_vig allmean_vig1 allmean_cnt_wr allmean_hr_wr;
run;
data work.pam_perperson;
  set pam_perperson;
run;
proc contents data=work.pam_perperson;
run;
proc contents data=work.pam_perminute;
run;
proc contents data=work.pam_perday;
run;

