package XML::XOXO::Node;
use strict;
use Class::XPath 1.4
     get_name => 'name',
     get_parent => 'parent',
     get_root   => 'root',
     get_children => sub { $_[0]->contents ? @{$_[0]->contents} : () },
     get_attr_names => sub { keys %{$_[0]->attributes} },
     get_attr_value => sub { $_[0]->attributes->{$_[1]} }, 
     get_content    => sub { $_[0]->attributes->{text} }
;

sub new {
    my $self = bless { }, $_[0];
    $self->{attributes} = { };
    $self->{contents} = [ ];
    $self;
}

sub name { my $this = shift; $this->stash('name',@_); }
sub parent { my $this = shift; $this->stash('parent',@_); }
sub contents { my $this = shift; $this->stash('contents',@_); }
sub attributes { my $this = shift; $this->stash('attributes',@_); }

sub root { 
    my $e = shift; 
    while($e->can('parent') && $e->parent) 
        { $e = $e->parent }
    $e; 
}

sub stash { 
    $_[0]->{$_[1]} = $_[2] if defined $_[2];
    $_[0]->{$_[1]};
}

#--- output

sub as_xml {
    my $this = shift;
    my $node = shift || $this;
    die 'A node is required when invoking as_xml as a class method.'
        unless ref($node);
    my $name = $node->name;    
    my $a = \%{ $node->attributes }; # cloned.
    my $children = $node->contents;
    my $out = "<$name>\n";
    # special attributes
    my $text = $a->{text} || $a->{title} || $a->{url}; 
    delete $a->{text};
    my $aa = '';
    if (exists $a->{url}) {
        $a->{href} = $a->{url};
        delete $a->{url};
    }
    map { $aa.=" $_=\"".encode_xml($a->{$_},1)."\""; delete $a->{$_}; }
        grep { exists $a->{$_} }
            qw( href title rel type );
    if (length($aa)) {
        $text = encode_xml($text,1);
        $out .= "<a$aa>$text</a>\n" ;
    }
    # extended (including multi-valued) attributes
    my $cout = '';
    foreach (sort keys %$a){
        $cout.= '<dt>'.encode_xml($_)."</dt>\n";
        $cout.= '<dd>';
        $cout.= ref($a->{$_}) ?
            "\n".$this->as_xml($a->{$_}) :
                encode_xml($a->{$_},1);
        $cout.= "</dd>\n";
    }
    $out .= "<dl>\n".$cout."</dl>\n" if length($cout);
    # children elements
    map { $out .= $this->as_xml($_) } @$children;
    $out .= "</$name>\n";
    $out;
}

my %Map = ('&' => '&amp;', '"' => '&quot;', '<' => '&lt;', '>' => '&gt;',
           '\'' => '&#39;');
my $RE = join '|', keys %Map;
sub encode_xml {
    my($str,$nocdata) = @_;
    return unless defined($str);
    if (!$nocdata && $str =~ m/
        <[^>]+>  ## HTML markup
        |        ## or
        &(?:(?!(\#([0-9]+)|\#x([0-9a-fA-F]+))).*?);
                 ## something that looks like an HTML entity.
    /x) {
        ## If ]]> exists in the string, encode the > to &gt;.
        $str =~ s/]]>/]]&gt;/g;
        $str = '<![CDATA[' . $str . ']]>';
    } else {
        $str =~ s!($RE)!$Map{$1}!g;
    }
    $str;
}

1;

