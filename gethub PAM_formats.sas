*----------------------------------------------------------------*;
*Formats for the PAM analysis data                               *;
*----------------------------------------------------------------*;
proc format;

value yesno
  1='Yes'
  0='No';

value wkday
  1='Sunday'
  2='Monday'
  3='Tuesday'
  4='Wednesday'
  5='Thursday'
  6='Friday'
  7='Saturday';

value gender
  1='Male'
  2='Female';

value agegrp
  0='All'
  1='6-11'
  2='12-15'
  3='16-19'
  4='20-29'
  5='30-39'
  6='40-49'
  7='50-59'
  8='60-69'
  9='70+';
run;
