#!/usr/bin/perl

$in = <STDIN>;
chomp($in);
@names = split(/\t/,$in);
$tot_columns = $#names;

$count = 1;
print "[";
while($in = <STDIN>){
 chomp($in);
 if($in =~ /./) {
  @flds = split(/\t/,$in);
  if($count > 1) { print "},\n";}
  print "{\n";
  for ($i=0;$i<$tot_columns;$i++) {
   print "\"$names[$i]\":\"$flds[$i]\",\n";
  } 
   print "\"$names[$#flds]\":\"$flds[$#flds]\"\n";
   $count++;
 }
}
print "}\n]\n";
