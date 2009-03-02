package Data::NDS::Multifile;
# Copyright (c) 2007-2009 Sullivan Beck. All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

###############################################################################
# GLOBAL VARIABLES
###############################################################################

###############################################################################
# TODO
###############################################################################

# Add DESC files which store a complete description of the structure
# (including path descriptions) which can be read in.

###############################################################################

require 5.000;
use strict;
use warnings;
use YAML::Syck;
use Data::NDS;
use Data::NDS::Multiele;
use Storable qw(dclone);

use vars qw($VERSION);
$VERSION = "3.00";

###############################################################################
# BASE METHODS
###############################################################################
#
# $NDS   always refers to a Data::NDS object
# $NME   always refers to a Data::NDS::Multiele object
# $nds   always refers to an actual NDS
# $ele   always refers to an element name/index
# $self  always refers to a Data::NDS::Multiele object

sub new {
   my(@args) = @_;

   # Get the Data::NDS object (if any).

   my $class = "Data::NDS::Multifile";
   my $NDS   = undef;

   if (@args  &&  ref($args[0]) eq $class) {
      # $obj = $self->new;

      my $self = shift(@args);
      $NDS     = $self->nds();

   } elsif (@args  &&  $args[0] eq $class) {
      # $obj = new Data::NDS::Multifile [NDS];

      shift(@args);
      if (@args &&  ref($args[0]) eq "Data::NDS") {
         $NDS  = shift(@args);
      } else {
         $NDS  = new Data::NDS;
      }

   } else {
      warn "ERROR: [new] first argument must be a $class class/object\n";
      return undef;
   }

   # Get the label/file args (if any)

   my @file = @args;

   my $self = {
               "nds"       => $NDS, # Data::NDS object
               "file"      => {},   # LABEL => Data::NDS::Multiele
               "labels"    => [],   # The order the labels are read in
               "list"      => "",   # 1 if data is a list
               "err"       => "",
               "errmsg"    => "",
               "elesx"     => [],   # Existing elements
               "elesn"     => [],   # Non-empty elements
               "eles"      => {},   # [ LABEL, FILE_ELE ]
                                    # Which file an element is in, and
                                    # the element in that file (this
                                    # differs for lists)
              };
   bless $self, $class;

   if (@file) {
      $self->file(@file);
      if ($self->err()) {
         return undef;
      }
   }

   return $self;
}

sub version {
   my($self) = @_;

   return $VERSION;
}

sub nds {
   my($self) = @_;

   return $$self{"nds"};
}

sub err {
   my($self) = @_;

   return $$self{"err"};
}

sub errmsg {
   my($self) = @_;

   return $$self{"errmsg"};
}

sub nme {
   my($self,$label) = @_;

   return $$self{"file"}{$label}  if (exists $$self{"file"}{$label});
   return undef;
}

###############################################################################
# FILE METHODS
###############################################################################

sub file {
   my($self,@args) = @_;
   $$self{"err"}    = "";
   $$self{"errmsg"} = "";

   if ($#args == 0) {
      $$self{"err"}    = "nmffil01";
      $$self{"errmsg"} = "An even number of arguements required to specify " .
        "files";
      return;
   }

   my $NDS = $self->nds();

   while (@args) {
      my $label = shift(@args);
      my $file  = shift(@args);

      # Check the label

      if (exists $$self{"file"}{$label}) {
         $$self{"err"}    = "nmffil02";
         $$self{"errmsg"} = "An attempt to reuse a file label already in " .
           "use: $label";
         return;
      }

      # Create a Data::NDS::Multiele object for the file

      my $obj   = new Data::NDS::Multiele($NDS,$file);

      if (! defined $obj) {
         $$self{"err"}    = "nmffil03";
         $$self{"errmsg"} = "An error occurred reading the data file: $file";
         return;
      }

      # Check to see that all files contain either lists or hashes

      if ($$self{"list"} eq "") {
         $$self{"list"} = $$obj{"list"};
      } elsif ($$self{"list"} != $$obj{"list"}) {
         $$self{"err"}    = "nmffil04";
         $$self{"errmsg"} = "All files must contain the same type of data: " .
           "$file";
         return;
      }

      # Add elements to "eles" hash

      $$self{"file"}{$label} = $obj;
      push(@{ $$self{"labels"} },$label);
   }

   _eles($self);
}

###############################################################################
# ELEMENT EXISTANCE METHODS
###############################################################################

sub _eles {
   my($self) = @_;

   $$self{"elesx"} = [];
   $$self{"elesn"} = [];
   $$self{"eles"}  = {};

   foreach my $label (@{ $$self{"labels"} }) {
      my $NME = $$self{"file"}{$label};

      my @elesx = $NME->eles(1);
      if ($NME->err()) {
         $$self{"err"}    = $NME->err();
         $$self{"errmsg"} = $NME->errmsg() . ": $label";
         $$self{"elesx"} = [];
         $$self{"elesn"} = [];
         $$self{"eles"}  = {};
         return undef;
      }
      my @elesn = $NME->eles();

      if ($$self{"list"}) {
         my $n = $#{ $$self{"elesx"} };
         foreach my $ele (@elesx) {
            my $i = $ele + $n + 1;
            $$self{"eles"}{$i} = [ $label, $ele ];
            $$self{"elesx"}[$i] = $i;
         }
         foreach my $ele (@elesn) {
            my $i = $ele + $n + 1;
            push @{ $$self{"elesn"} },$i;
         }

      } else {
         push @{ $$self{"elesx"} },@elesx;
         push @{ $$self{"elesn"} },@elesn;
         foreach my $ele (@elesx) {
            if (exists $$self{"eles"}{$ele}) {
               my $l1           = $$self{"eles"}{$ele}[0];
               $$self{"err"}    = "nmffil05";
               $$self{"errmsg"} = "A data element is duplicated in 2 files: " .
                 "$ele [$l1, $label]";
               $$self{"elesx"}  = [];
               $$self{"elesn"}  = [];
               $$self{"eles"}   = {};
               return;
            }

            $$self{"eles"}{$ele} = [ $label,$ele ];
         }
      }
   }

   if (! $$self{"list"}) {
      @{ $$self{"elesx"} } = sort @{ $$self{"elesx"} };
      @{ $$self{"elesn"} } = sort @{ $$self{"elesn"} };
   }
}

sub eles {
   my($self,$exists) = @_;
   $$self{"err"}    = "";
   $$self{"errmsg"} = "";

   if ($exists) {
      return @{ $$self{"elesx"} }  if (@{ $$self{"elesx"} });
   } else {
      return @{ $$self{"elesn"} }  if (@{ $$self{"elesn"} });
   }

   _eles($self);
   return  if ($self->err());

   if ($exists) {
      return @{ $$self{"elesx"} }  if (@{ $$self{"elesx"} });
   } else {
      return @{ $$self{"elesn"} }  if (@{ $$self{"elesn"} });
   }
}

sub ele {
   my($self,$ele,$exists) = @_;
   $$self{"err"}    = "";
   $$self{"errmsg"} = "";

   return 0  if (! exists $$self{"eles"}{$ele});

   my($label,$fele) = @{ $$self{"eles"}{$ele} };
   my $NME          = $$self{"file"}{$label};

   my $ret          = $NME->ele($fele,$exists);
   if ($NME->err()) {
      $$self{"err"}    = $NME->err();
      $$self{"errmsg"} = $NME->errmsg() . ": $label";
      return undef;
   }

   return $ret;
}

sub ele_file {
   my($self,$ele) = @_;

   if (! $self->ele($ele)) {
      $$self{"err"}    = "nmfele01";
      $$self{"errmsg"} = "The specified element does not exist: $ele";
      return "";
   }

   return $$self{"eles"}{$ele}[0];
}

sub _ele_nme {
   my($self,$ele) = @_;

   if (! $self->ele($ele)) {
      $$self{"err"}    = "nmfele01";
      $$self{"errmsg"} = "The specified element does not exist: $ele";
      return "";
   }

   my $label = $$self{"eles"}{$ele}[0];
   my $fele  = $$self{"eles"}{$ele}[1];
   return ($$self{"file"}{$label},$fele);
}

###############################################################################
# DEFAULT METHODS
###############################################################################

sub default_element {
   my($self,@args)  = @_;
   $$self{"err"}    = "";
   $$self{"errmsg"} = "";

   # Get the Multiele object containing the default.

   my $label;
   if ($$self{"list"}) {
      #
      # Lists = (LABEL [RULESET] [PATH,VAL,...])
      #
      $label = shift(@args);
      if (! exists $$self{"file"}{$label}) {
         $$self{"err"}    = "nmffil06";
         $$self{"errmsg"} = "An invalid file label was used: $label";
         return undef;
      }

   } else {
      #
      # Hashes = (ELE [RULESET] [PATH,VAL,...])
      #
      my $ele = $args[0];
      if (! exists $$self{"eles"}{$ele}) {
         $$self{"err"}    = "nmfele01";
         $$self{"errmsg"} = "Attempt to access an undefined element: $ele";
         return undef;
      }
      $label = $$self{"eles"}{$ele}[0];
   }

   my $NME = $$self{"file"}{$label};

   # Handle the default, and then regenerate element lists.

   $NME->default_element(@args);
   if ($NME->err()) {
      $$self{"err"}    = $NME->err();
      $$self{"errmsg"} = $NME->errmsg() . ": $label";
      return undef;
   }

   _eles($self);
}

sub is_default_value {
   my($self,$ele,$path) = @_;
   $$self{"err"}    = "";
   $$self{"errmsg"} = "";

   if (! $self->ele($ele,1)) {
      $$self{"err"}    = "nmfele01";
      $$self{"errmsg"} = "The specified element does not exist: $ele";
      return;
   }

   if (! $self->path_valid($path)) {
      $$self{"err"}    = "nmeacc03";
      $$self{"errmsg"} = "Attempt to access data with an invalid path: $path";
      return undef;
   }

   my($label,$fele) = @{ $$self{"eles"}{$ele} };
   my $NME          = $$self{"file"}{$label};

   my $ret          = $NME->is_default_value($fele,$path);
   if ($NME->err()) {
      $$self{"err"}    = $NME->err();
      $$self{"errmsg"} = $NME->errmsg() . ": $label";
      return undef;
   }

   return $ret;
}

###############################################################################
# WHICH METHOD
###############################################################################

sub which {
   my($self,@cond)  = @_;

   if ($$self{"list"}) {
      return _which_list($self,@cond);
   } else {
      return _which_hash($self,@cond);
   }
}

sub _which_list {
   my($self,@cond)  = @_;

   my @ele = ();
   my $n   = 0;
   foreach my $label (@{ $$self{"labels"} }) {
      my $NME = $$self{"file"}{$label};

      my @tmp = $NME->which(@cond);
      if ($NME->err()) {
         $$self{"err"}    = $NME->err();
         $$self{"errmsg"} = $NME->errmsg() . ": $label";
         return ();
      }

      push @ele, map { $_ + $n } @tmp;

      @tmp = $NME->eles(1);
      $n  += $#tmp + 1;
   }

   return @ele;
}

sub _which_hash {
   my($self,@cond)  = @_;

   my @ele = ();
   while (my($label,$NME) = each %{ $$self{"file"} }) {
      my @tmp = $NME->which(@cond);
      if ($NME->err()) {
         $$self{"err"}    = $NME->err();
         $$self{"errmsg"} = $NME->errmsg() . ": $label";
         return ();
      }
      push(@ele,@tmp);
   }
   @ele = sort @ele;
   return @ele;
}

###############################################################################
# PATH_VALID METHOD
###############################################################################

sub path_valid {
   my($self,$path) = @_;
   my $NDS = $$self{"nds"};

   return $NDS->get_structure($path,"valid");
}

###############################################################################
# VALUE, KEYS, VALUES METHODS
###############################################################################

sub value {
   my($self,$ele,$path,@args) = @_;
   $$self{"err"}    = "";
   $$self{"errmsg"} = "";

   my $NME;
   ($NME,$ele) = _ele_nme($self,$ele);
   return undef  if ($self->err());

   my $val = $NME->value($ele,$path,@args);
   if ($NME->err()) {
      $$self{"err"}    = $NME->err();
      $$self{"errmsg"} = $NME->errmsg();
      return undef;
   }

   return $val;
}

sub keys {
   my($self,$ele,$path,@args) = @_;
   $$self{"err"}    = "";
   $$self{"errmsg"} = "";

   my $NME;
   ($NME,$ele) = _ele_nme($self,$ele);
   return undef  if ($self->err());

   my @val = $NME->keys($ele,$path,@args);
   if ($NME->err()) {
      $$self{"err"}    = $NME->err();
      $$self{"errmsg"} = $NME->errmsg();
      return undef;
   }

   return @val;
}

sub values {
   my($self,$ele,$path,@args) = @_;
   $$self{"err"}    = "";
   $$self{"errmsg"} = "";

   my $NME;
   ($NME,$ele) = _ele_nme($self,$ele);
   return undef  if ($self->err());

   my @val = $NME->values($ele,$path,@args);
   if ($NME->err()) {
      $$self{"err"}    = $NME->err();
      $$self{"errmsg"} = $NME->errmsg();
      return undef;
   }

   return @val;
}

###############################################################################
# PATH_VALUES METHOD
###############################################################################

sub path_values {
   my($self,@args) = @_;
   $$self{"err"}    = "";
   $$self{"errmsg"} = "";

   my @ret;

   my $prev         = 0;
   foreach my $label (@{ $$self{"labels"} }) {
      my $NME = $$self{"file"}{$label};

      my @tmp = $NME->path_values(@args);
      if ($NME->err()) {
         $$self{"err"}    = $NME->err();
         $$self{"errmsg"} = $NME->errmsg() . ": $label";
         return undef;
      }

      if ($$self{"list"}) {
         while (@tmp) {
            my $e = shift(@tmp);
            my $v = shift(@tmp);
            push(@ret,$e+$prev,$v);
         }
         my @ele = $NME->eles(1);
         $prev += $#ele + 1;
      } else {
         push(@ret,@tmp);
      }
   }

   return @ret;
}

###############################################################################
# DELETE_ELE METHOD
###############################################################################

sub delete_ele {
   my($self,$ele) = @_;
   $$self{"err"}    = "";
   $$self{"errmsg"} = "";

   my $NME;
   ($NME,$ele) = _ele_nme($self,$ele);
   return undef  if ($self->err());

   $NME->delete_ele($ele);
   if ($NME->err()) {
      $$self{"err"}    = $NME->err();
      $$self{"errmsg"} = $NME->errmsg();
      return undef;
   }
   _eles($self);
   return;
}

###############################################################################
# RENAME_ELE METHOD
###############################################################################

sub rename_ele {
   my($self,$ele,$newele) = @_;
   $$self{"err"}    = "";
   $$self{"errmsg"} = "";

   my $NME;
   ($NME,$ele) = _ele_nme($self,$ele);
   return undef  if ($self->err());

   $NME->rename_ele($ele,$newele);
   if ($NME->err()) {
      $$self{"err"}    = $NME->err();
      $$self{"errmsg"} = $NME->errmsg();
      return undef;
   }
   _eles($self);
   return;
}

###############################################################################
# ADD_ELE METHOD
###############################################################################

sub add_ele {
   my($self,@args) = @_;

   if ($$self{"list"}) {
      return _add_ele_list($self,@args);
   } else {
      return _add_ele_hash($self,@args);
   }
}

sub _add_ele_list {
   my($self,@args) = @_;

   # Parse arguments

   my($label,$ele,$nds,$new);
   $ele = "";

   if ($#args == 0) {
      # $nds
      ($nds) = @args;

   } elsif ($#args == 1) {
      # $nds,$new
      # $ele,$nds
      # $label,$nds

      if (exists $$self{"file"}{$args[0]}) {
         ($label,$nds) = @args;
      } elsif (ref($args[0])) {
         ($nds,$new) = @args;
      } else {
         ($ele,$nds) = @args;
      }

   } elsif ($#args == 2) {
      # $ele,$nds,$new
      # $label,$nds,$new
      if (exists $$self{"file"}{$args[0]}) {
         ($label,$nds,$new) = @args;
      } else {
         ($ele,$nds,$new) = @args;
      }

   } else {
      die "ERROR: add_ele: unknown arguments: @args\n";
   }

   # Check each argument

   if ($label  &&  ! exists $$self{"file"}{$label}) {
      $$self{"err"}    = "nmffil06";
      $$self{"errmsg"} = "An invalid file label was used: $label";
      return undef;
   }

   if ($ele ne ""  &&  ! exists $$self{"eles"}{$ele}) {
      $$self{"err"}    = "nmfele01";
      $$self{"errmsg"} = "Attempt to access an undefined element: $ele";
      return undef;
   }

   # Add the element

   my $NME;
   my @a;
   if ($label) {
      # Push onto list of the given file
      @a = ($nds);

   } elsif ($ele ne "") {
      # Insert into the list at $ele

      my($fele);
      ($label,$fele) = @{ $$self{"eles"}{$ele} };
      @a = ($fele,$nds);

   } else {
      # Push onto the last file.
      $label = $$self{"labels"}[ $#{ $$self{"labels"} } ];
      @a = ($nds);
   }

   $NME = $$self{"file"}{$label};
   $NME->add_ele(@a);

   if ($NME->err()) {
      $$self{"err"}    = $NME->err();
      $$self{"errmsg"} = $NME->errmsg();
      return undef;
   }
   _eles($self);
   return;
}

sub _add_ele_hash {
   my($self,@args) = @_;

   # Parse arguments

   my($label,$ele,$nds,$new);
   if (exists $$self{"file"}{$args[0]}) {
      ($label,$ele,$nds,$new) = @args;
   } else {
      ($ele,$nds,$new) = @args;
   }

   # Check each argument

   if (ref($ele)) {
      $$self{"err"}    = "nmfele04";
      $$self{"errmsg"} = "When adding an element, a name must be given.";
      return undef;
   }

   if ($label  &&  ! exists $$self{"file"}{$label}) {
      $$self{"err"}    = "nmffil06";
      $$self{"errmsg"} = "An invalid file label was used: $label";
      return undef;
   }

   if ($ele eq "") {
      $$self{"err"}    = "nmfele03";
      $$self{"errmsg"} = "When accessing a hash element, a name must be given.";
      return undef;
   }

   if (exists $$self{"eles"}{$ele}) {
      $$self{"err"}    = "nmfele02";
      $$self{"errmsg"} = "Attempt to overwrite an existing element: $ele";
      return undef;
   }

   # Add the element

   $label = $$self{"labels"}[ $#{ $$self{"labels"} } ]
     if (! $label);
   my $NME = $$self{"file"}{$label};
   $NME->add_ele($ele,$nds);

   if ($NME->err()) {
      $$self{"err"}    = $NME->err();
      $$self{"errmsg"} = $NME->errmsg();
      return undef;
   }
   _eles($self);
   return;
}

###############################################################################
# COPY_ELE METHOD
###############################################################################

sub copy_ele {
   my($self,$ele,@args) = @_;

   # Check to make sure $ele is valid (it need only exist)

   if (! $self->ele($ele)) {
      $$self{"err"}    = "nmfele01";
      $$self{"errmsg"} = "The specified element does not exist: $ele";
      return "";
   }

   # Get the structure there.

   my $file = $self->ele_file($ele);
   my $NME  = (_ele_nme($self,$ele))[0];
   my $nds  = dclone($NME->_nds($ele,1));

   if (! @args  ||  ! exists $$self{"file"}{$args[0]}) {
      # The first argument is not a label, so prepend the label of the
      # original element.
      unshift(@args,$file);
   }

   add_ele($self,@args,$nds);
}

###############################################################################
# UPDATE_ELE METHOD
###############################################################################

sub update_ele {
   my($self,$ele,@args) = @_;
   $$self{"err"}    = "";
   $$self{"errmsg"} = "";

   my $NME;
   ($NME,$ele) = _ele_nme($self,$ele);
   return undef  if ($self->err());

   $NME->update_ele($ele,@args);
   if ($NME->err()) {
      $$self{"err"}    = $NME->err();
      $$self{"errmsg"} = $NME->errmsg();
      return undef;
   }
   _eles($self);
   return;
}

###############################################################################
# DUMP METHOD
###############################################################################

sub dump {
   my($self,$ele,@args) = @_;
   $$self{"err"}    = "";
   $$self{"errmsg"} = "";

   my $NME;
   ($NME,$ele) = _ele_nme($self,$ele);
   return undef  if ($self->err());

   my $ret = $NME->dump($ele,@args);
   if ($NME->err()) {
      $$self{"err"}    = $NME->err();
      $$self{"errmsg"} = $NME->errmsg();
      return undef;
   }
   return $ret;
}

###############################################################################
# SAVE METHOD
###############################################################################

sub save {
   my($self,$nobackup) = @_;

   while (my($label,$NME) = each %{ $$self{"file"} }) {
      $NME->save($nobackup);
      if ($NME->err()) {
         $$self{"err"}    = $NME->err();
         $$self{"errmsg"} = $NME->errmsg() . ": $label";
         return undef;
      }
   }
   return;
}

1;
# Local Variables:
# mode: cperl
# indent-tabs-mode: nil
# cperl-indent-level: 3
# cperl-continued-statement-offset: 2
# cperl-continued-brace-offset: 0
# cperl-brace-offset: 0
# cperl-brace-imaginary-offset: 0
# cperl-label-offset: -2
# End:
