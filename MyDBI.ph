use Mysql;

package MyDBI;
##############################
# @array = getFields ($dbh,$table)
# Returns a list of column names
sub main::getFields {
  my ($db,$tbl) = @_;
  my $qh = $dbh->listfields($tbl);
  if ($qh) {
    my @columns = $qh->fetchrow;
    return @columns;
  }
  else {
    return undef;
  }
}

# getRowsAsHash($dbhandle,$table,$condition,$sort)
# - A general purpose function to retrieve row(s) from a table.
# - Returns a reference to an array of hashes where the hash keys are column
#   names and the array index is the row number
sub main::getRowsAsHash {
  my ($db,$varlist,$tbl,$condition, $order) = @_;
  my ($qh,$i,$a,$q);
  $q = "select ";
  $q .= $varlist ? $varlist : '*';
  $q .= " from $tbl";
  $q .= " where $condition" if $condition;
  $q .= " order by $order" if $order;
  # main::debug("getRowsAsHash: [$q]");
  $qh = $db->query($q);
  if ($qh) {
    $i = 0;
    while ($i < $qh->numrows) {
      %{$a->[$i]} = $qh->fetchhash;
      $i++;
    }
    return ($a);
  }
  else {
    return (undef);
  }
}

# getRow ($dbhandle,$varlist,$table,$condition,$sort)
# - A general purpose function to retrieve just the first row of the results.
# - Returns a reference to hash where the hash keys are column
#   names and the hash values are the column value.
sub main::getRow {
  my ($db,$varlist,$tbl,$condition,$order) = @_;
  my ($qh,$i,$a,$q);
  $q = "select ";
  $q .= $varlist ? $varlist : '*';
  $q .= " from $tbl";
  $q .= " where $condition" if $condition;
  $q .= " order by $order" if $order;
  # main::debug("getRowsAsHash: [$q]");
  $qh = $db->query($q);
  if ($qh) {
    %{$a} = $qh->fetchhash;
    return ($a);
  }
  else {
    return (undef);
  }
}

##############################
# $string = buildSqlCondition ($hRef)
sub main::buildSqlCondition {
  my $h = shift @_;
  my ($key,$condition);
  $condition = '';
  foreach $key (keys %$h) {
    $condition .= "$key='$h->{$key}' and ";
  }
  $condition =~ s/ and $//;
  return $condition;
}

##############################
# $num = updateTable($DB,$table,$where_clause,$data_hash)
# $DB - database name
# $table - table name
# $where_clause - a string containing the condition that identifies the record(s) to be updated
# $data_hash - pointer to a hash that contains data to be updated. The hash key is the column name
#     and the hash value is the data
# Returns either the number of rows affected or undef on error.
# If the $where_clause specifies a non-existant record a new record is inserted using data specified
#     in the $data_hash.
sub main::updateTable {
  my ($db, $table, $where, $hash) = @_;
  my ($n, $qh, $q, $key);
  $q = '';
  foreach $key (keys %{$hash}) {
    if ($hash->{$key} =~ /^MYSQL_FUNC:(.+)$/) {
      $q .= "`$key`=$1, ";
    }
    else {
      $q .= "`$key`=".$db->quote($hash->{$key}).", ";
    }
  }
  $q =~ s/, $//;
#  main::debug("updateTable: [$q]");

  unless ($where && ($n = main::getRowsAsHash($db,undef,$table,$where))) {
    $qh = $db->query("insert into $table set $q");
    if ($db->errmsg) {
      return (undef);
    }
    return ($qh->affectedrows());
  }
  else {
    $qh = $db->query("update $table set $q where $where");
    if ($db->errmsg) {
      return (undef);
    }
    return ($qh->affectedrows());
  }
}

##############################
# int delRowFrom ($db,$table,$condition);
sub main::delRowFrom {
  my ($db,$table,$where) = @_;
#  main::debug("delRowFrom: [$where]");
  my $qh = $db->query("delete from $table where $where");
  if ($db->errmsg) {
    return undef;
  }
  return $qh->affectedrows();
}

1;
