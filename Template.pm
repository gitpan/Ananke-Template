#!/usr/bin/perl

package Ananke::Template;
use strict;

my $VERSION = '1.0'; 
my @my;

# Inicia modulo
sub new {
	my($self,$templ_dir) = @_;

	# Grava dados
	bless {
		'TEMPL_DIR' => $templ_dir,
	}, $self;
}

# Processa p�gina
sub process {
	my($self,$file,$vars) = @_;
	my($fdata,$output,$my);
	$self->{TEMPL_FILE} = $file;
	@my = ();

	$fdata = $self->load();
	$output = $self->parse($fdata,$vars);
	
	foreach (@my) {
		$my .=  $_->{value};
	}

	$output = $my.$output;

	open(FH,">>/tmp/filex");
	syswrite(FH,$output);
	close(FH);

	#print $output;
	eval $output;
	print $@;
}

# Trata arquivo
sub parse {
	my($self,$fdata,$vars) = @_;
	my(@t,$ndata,$output);

	# Transfere dados para vars
	foreach (keys %{$vars}) {
		push(@my,{
			var	=> "\$T$_",
			value => "my \$T$_ = \$vars->{$_};\n"
		});
	}
	
	# Adiciona \ em caracteres nao permitidos
	my $Tstart = quotemeta("[%");
	my $Tend = quotemeta("%]");

	# Faz o primeiro parse
	while ($fdata) {

		# Verifica parse
		if ($fdata =~ s/^(.*?)?(?:$Tstart(.*?)$Tend)//sx) {
	
			$t[1] = $1; $t[2] = $2;
			$t[1] =~ s/[\n|\s]//g if ($t[1] =~ /^[\n\s]+$/);

			# Nao executa linhas comentadas e espacos desnecessarios
			$t[2] =~ s/^\s+?\#\s+(.*?)\s+?$//g;
			$t[2] =~ s/^\s+?(.*?)\s+?$/$1/g;

			if ($t[1]) {
				$t[1] = "\nprint \"".&AddSlashes($t[1])."\";";
			}
		
			# Retira espa�os em branco no come�o e final da var
			$t[2] =~ s/^[ ]+?(.*)[ ]+?$/$1/s;
			
			# Trata if e elsif
			if ($t[2] =~ /^(IF|ELSIF|UNLESS)\s+(.*)$/i) {
				$t[3] = lc($1);
				$t[4] = $2;
				$t[4] =~ s/AND/\&\&/g; $t[4] =~ s/OR/\|\|/g;
			
				$t[3] = "} ".$t[3] if ($t[3] eq "elsif");
			
				# Trata todos os tipos de vars
				while ($t[4] =~ /([\&\|\s\>\<\=\%]+)?([a-zA-Z0-9\"\'\_\.\+\-]+)([\&\|\s\>\<\=\%]+)?/g) {
					$t[5] = $1; $t[6] = $2; $t[7] = $3;

					# vars scalares
					if ($t[6] =~ /^([a-zA-Z\_]+)\.([a-zA-Z\_]+)$/) {
						$t[6] = "\$T".$1."->{$2}";
						$self->my("\$T".$1."->{$2}");
					}
				
					# Demais variaveis
					elsif ($t[6] =~ /^([a-zA-Z\_]+)$/) {
						$self->my("\$T".$t[6]);
						$t[6] = "\$T".$t[6];
					}
					
					# String ou numeros
					elsif ($t[6] =~ /^([a-zA-Z0-9\"\']+)$/) {
						$t[6] = $1;
					}
					
					# vars normais
					#else {
					#}

					$t[8] .= $t[5].$t[6].$t[7];
				}

				$t[2] = "\n".$t[3]." (".$t[8].") {";

				undef $t[3]; undef $t[4]; undef $t[5];
				undef $t[6]; undef $t[7]; undef $t[8];
			}

			# Trata for
			elsif ($t[2] =~ /(FOR) (.*)/) {
				$t[8] = $1;
				$t[3] = $2;
	
				# Trata opcoes do for
				while ($t[3] =~ /([\;])?([a-zA-Z0-9\_\.\+\-]+)([\<\=\>]+)?/g) {
					$t[4] = $2; $t[5] = $3; $t[6] = $1;
					
					# Trata hash
					if ($t[4] =~ /([a-zA-Z]+)\.([a-zA-Z]+)/) {
						$self->my("\$T".$1."->{$2}");
						$t[4] = "\$T".$1."->{$2}";
					} 
					
					# Trata vars
					else {
						if ($t[4] =~ /[0-9]+/) {
							$t[4] = $t[4];
						} else {
							$self->my("\$T".$t[4]);
							$t[4] = "\$T".$t[4];
						}
					}

					$t[7] .= "$t[6]$t[4]$t[5]";
				}

				$t[2] = "\n".lc($t[8])." (".$t[7].") {";
				
				undef $t[3]; undef $t[4]; undef $t[5];
				undef $t[6]; undef $t[7]; undef $t[8];
			}

			# Trata foreach
			elsif ($t[2] =~ /(FOREACH) (.*) = (.*)/i) {
				
				# Seta vars do if
				$t[3] = $1; $t[4] = $2; $t[5] = $3;

				# Verifica se � hash
				if (ref $vars->{$t[5]} eq "ARRAY") {
					$t[2] = "\n".lc($1)." my \$T$2 (\@{\$T$3}) {";
					$self->my("\@T$3");
				}

				# Caso nao exista array
				else {
					$t[2] = "\n".lc($1)." my \$T$2 (\@\{0\}) {";
				}

				# apaga vars do if
				undef $t[3]; undef $t[4]; undef $t[5];
			}

			# Fecha sintaxy
			elsif ($t[2] eq "END") {
				$t[2] = "\n}";
			}

			# Else
			elsif ($t[2] eq "ELSE") {
				$t[2] = "\n} else {";
			}

			# Adiciona include
			elsif ($t[2] =~ /^INCLUDE\s+(.*)$/) {
			   $ndata = $self->load($1);
				$t[2] = $self->parse($ndata);
			}

			# Trata hash
			elsif ($t[2] =~ /([a-zA-Z\_]+)\.([a-zA-Z\_]+)/) {
				$t[2] = "\nprint \$T".$1."->{".$2."};";
				$self->my("\$T".$1."->{".$2."}");
			}

			# Trata string
			elsif ($t[2] =~ /^[a-zA-Z0-9\_]$/) {
				$self->my("\$T".$t[2]);
				$t[2] = "\nprint \$T".$t[2].";";
			}

			# Seta vars
			elsif ($t[2] =~ /^([a-zA-Z0-9\_\+\-]+)\s?([\=\>\<]+)?\s?[\"]?(.*)?[\"]?$/) {
				$t[3] = $1; $t[4] = $2; $t[5] = $3;

				# Trata variaveis unica
				if ($t[3] && !$t[5]) {
					
					# Variaveis
					if ($t[3] =~ /^[a-zA-Z0-9\_]+$/) {
						$self->my("\$T".$t[3]);
						$t[2] = "\nprint \$T".$t[3].";";
					}
					
					# Variaveis especiais
					elsif ($t[3] =~ /^[a-zA-Z0-9\_\+\-]+$/) {
						$self->my("\$T".$t[3]);
						$t[2] = "\n\$T".$t[3].";";
					}
				}
				
				# Seta variaveis
				elsif ($t[3] && $t[5]) {
					$self->my("\$T".$t[3]);
					$t[2] = "\n\$T".$t[3]." $t[4] \"".&AddSlashes($t[5])."\";";
				}
			}
	
			$output .= $t[1].$t[2];
		}

		# Outros
		elsif ($fdata =~ s/^(.*)$//sx) {
			$output .= "\nprint \"".&AddSlashes($1)."\";\n";
		}
	}

	return $output;
}

# Verifica se adicionou no array
sub my {
	my($self,$var) = @_;
	my (@t,$t);

	if ($var =~ /^([\$\@\%])(.*)?$/) {
		$t[1] = $1; $t[2] = $2;
	
		# Trata array
		if ($t[1] eq "\@") {
			# Verifica se ja esta no array
			$t = 1;
			foreach (@my) { if ($_->{var} eq "\@".$t[2]) { undef $t } }
			
			# Adiciona no array
			push(@my,{
				var	=> "\@".$t[2],
				value	=> "my \@".$t[2].";\n",
			}) if ($t);

			undef $t;
		}

		# Trata var
		elsif ($t[1] eq "\$" && $t[2] =~ /^([\w\+]+)([\-\>]+)?([\w\{\}]+)?/g) {
			$t[3] = $1;
			$t[3] =~ s/\+//g; $t[3] =~ s/\-//g;
	
			# Verifica se ja esta no array
			$t = 1;
			foreach (@my) { 
				if ($_->{var} eq "\$".$t[3]) { 
					undef $t;
					last;
				}
			}
			
			# Adiciona no array
			push(@my,{
				var	=> "\$".$t[3],
				value	=> "my \$".$t[3].";\n",
			}) if ($t);
			
			undef $t;
		}
	}
}

# Abre aquivo
sub load {
	my($self,$templ_file) = @_;
	my($r,$fdata);
	my $path;
	my $file = $templ_file || $self->{TEMPL_FILE};
	my $templ_path = $self->{TEMPL_DIR}."/".$file;

	local $/ = undef;
	#local *FH;

	# Abre arquivo
	if (open(FH,$templ_path)) {
		$fdata = <FH>;
		
		open(FH2,">>/tmp/filexx");
		syswrite(FH2,$fdata);
		close(FH2);

		# Fecha arquivo
		close(FH);
	}

	# Retorna erro
	else {
		die "Erro abrindo arquivo $templ_path: $!\n";
	}

	# Retorna dados
	return $fdata;
}

# Adiciona barras invertidas
sub AddSlashes {
	my($str) = @_;

	$str =~ s/\\/\\\\/g;
	$str =~ s/\#/\\#/g;
	$str =~ s/\@/\\@/g;
	$str =~ s/\"/\\"/g;
	
	return $str;
}

1;
__END__

=head1 NAME

Ananke::Template - Front-end module to the Ananke::Template

=head1 DESCRIPTION

Based in Template ToolKit
This documentation describes the Template module which is the direct
Perl interface into the Ananke::Template.

=head1 SYNOPSIS 

=head2 Template.pl:

	use Ananke::Template;

	# Vars
	my @array;
	push(@array,{ name => 'Udlei', last => 'Nattis' });
	push(@array,{ name => 'Ananke', last => 'IT' });

	my $var = {
		id => 1,
		title => 'no title',
		text  => 'no text',
	};

	# Template Directory and File
	my $template_dir = "./";
	my $template_file = "template.html";
	my $template_vars = {
		'hello'  => "\nhello world",
		'scalar' => $var,
		'array'  => ['v1','v2','v3','v4'],
		'register' => \@array,
	};
	$template_vars->{SCRIPT_NAME} = "file.pl";

	# Create template object
	my $template = new Ananke::Template($template_dir);

	# Run Template
	$template->process($template_file,$template_vars);

=head2 template.html:

	[% hello %]

	[% IF scalar %]
		ID: [% scalar.id %]
		Title: [% scalar.title %]
		Text: [% scalar.text %]
	[% END %]

	[% FOREACH i = array %]
		value = [% i %]
	[% END %]

	[% FOREACH i = register %]
		Nome = [% i.name %], Last = [% i.last %]
	[% END %]

=head1 DIRECTIVE

=head2 INCLUDE

Process another template file or block and include the output.  Variables are localised.

	[% INCLUDE template %]
	[% INCLUDE ../template.html %]

=head2 FOREACH

Repeat the enclosed FOREACH ... END block for each value in the list.

	[% FOREACH variable = list %]                 
		content... 
		[% variable %]
	[% END %]

	# or

	[% FOREACH i = list_chn_grp %]
		[% count++ %]
		[% IF count % 2 %] [% bgcolor = "#FFFFFF" %]
		[% ELSE %] [% bgcolor = "#EEEEEE" %]
		[% END %]
	
		[% i.bgcolor %]
	[% END %]

=head2 IF / UNLESS / ELSIF / ELSE

Enclosed block is processed if the condition is true / false.

	[% IF condition %]
		content
	[% ELSIF condition %]
		content
	[% ELSE %]
		content
	[% END %]

	[% UNLESS condition %]
		content
	[% # ELSIF/ELSE as per IF, above %]
		content
	[% END %]

=head2 FOR

	[% FOR i=1;i<=12;i++ %]
		[% i=1 %]
	[% END %]

=head2 VARIABLES

	[% var = 'text' %]
	[% var %]

=head1 AUTHOR

	Udlei D. R. Nattis
	nattis@anankeit.com.br
	http://www.nobol.com.br
	http://www.anankeit.com.br

=cut

# Data inicio: Thu Feb 21 16:19:18 BRT 2002
# Desenvolvido por: Udlei Nattis <nattis@anankeit.com.br>


