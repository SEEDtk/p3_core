#
# Copyright (c) 2003-2015 University of Chicago and Fellowship
# for Interpretations of Genomes. All Rights Reserved.
#
# This file is part of the SEED Toolkit.
#
# The SEED Toolkit is free software. You can redistribute
# it and/or modify it under the terms of the SEED Toolkit
# Public License.
#
# You should have received a copy of the SEED Toolkit Public License
# along with this program; if not write to the University of Chicago
# at info@ci.uchicago.edu or the Fellowship for Interpretation of
# Genomes at veronika@thefig.info or download a copy from
# http://www.theseed.org/LICENSE.TXT.
#

# This is a SAS Component

package P3Utils;

    use strict;
    use warnings;
    use Getopt::Long::Descriptive;
    use Data::Dumper;
    use LWP::UserAgent;
    use HTTP::Request;
    use SeedUtils;
    use Digest::MD5;
    use RoleParse;
    use P3View;

=head1 PATRIC Script Utilities

This module contains shared utilities for PATRIC 3 scripts.

The bulk of this module is concerned with presenting a model for using the PATRIC database. The model is
defined by various constants that translate table and field names to more user-friendly versions and
present derived fields.

This process is complicated by the existence of views. A set of field names can be translated (post-view) or
untranslated (pre-view). Every method that deals with field names must be aware of whether it is translated
or not. The L<P3View> object that manages the translations is kept in the L<P3DataAPI> object that is passed
to most methods. In general, column names and header lists are always untranslated. The major translators
are L<P3Utils::select_clause> and L<P3Utils::form_filter>, which take untranslated (pre-view) names as input
and produce translated names on the output.

=head2 Constants

These constants define the sort-of ER model for PATRIC.

=head3 OBJECTS

Mapping from user-friendly names to PATRIC names.

=cut

use constant OBJECTS => {   genome => 'genome',
                            feature => 'genome_feature',
                            family => 'protein_family_ref',
                            genome_drug => 'genome_amr',
                            contig =>  'genome_sequence',
                            drug => 'antibiotics',
                            taxonomy => 'taxonomy',
                            experiment => 'transcriptomics_experiment',
                            expression => 'transcriptomics_gene',
                            sample => 'transcriptomics_sample',
                            sequence => 'feature_sequence',
                            subsystem => 'subsystem_ref',
                            subsystemItem => 'subsystem',
                            alt_feature => 'genome_feature',
                            sp_gene => 'sp_gene',
                            protein_region => 'protein_feature',
                            protein_structure => 'protein_structure',
                            surveillance => 'surveillance',
                            serology => 'serology',
                            sf => 'sequence_feature',
                            sfvt => 'sequence_feature_vt'
};

=head3 FIELDS

Mapping from user-friendly object names to default fields.

=cut

use constant FIELDS =>  {   genome => ['genome_name', 'genome_id', 'genome_status', 'sequences', 'patric_cds', 'isolation_country', 'host_name', 'disease', 'collection_year', 'completion_date'],
                            feature => ['patric_id', 'refseq_locus_tag', 'gene_id', 'plfam_id', 'pgfam_id', 'product'],
                            alt_feature => ['feature_id', 'refseq_locus_tag', 'gene_id', 'product'],
                            family => ['family_id', 'family_type', 'family_product'],
                            genome_drug => ['genome_id', 'antibiotic', 'resistant_phenotype'],
                            contig => ['genome_id', 'accession', 'length', 'gc_content', 'sequence_type', 'topology'],
                            drug => ['cas_id', 'antibiotic_name', 'canonical_smiles'],
                            experiment => ['eid', 'title', 'genes', 'pmid', 'organism', 'strain', 'mutant', 'timeseries', 'release_date'],
                            sample => ['eid', 'expid', 'genes', 'sig_log_ratio', 'sig_z_score', 'pmid', 'organism', 'strain', 'mutant', 'condition', 'timepoint', 'release_date'],
                            expression => ['id', 'eid', 'genome_id', 'patric_id', 'refseq_locus_tag', 'alt_locus_tag', 'log_ratio', 'z_score'],
                            taxonomy => ['taxon_id', 'taxon_name', 'taxon_rank', 'genome_count', 'genome_length_mean'],
                            sequence => ['md5', 'sequence_type', 'sequence'],
                            sp_gene => ['evidence', 'property', 'patric_id', 'refseq_locus_tag', 'source_id', 'gene', 'product', 'pmid', 'identity', 'e_value'],
                            subsystem => ['subsystem_id', 'subsystem_name', 'superclass', 'class', 'subclass'],
                            subsystemItem => ['id', 'subsystem_name', 'superclass', 'class', 'subclass', 'subsystem_name', 'role_name', 'active',
                                        'patric_id', 'gene', 'product'],
                            protein_region => ['patric_id', 'refseq_locus_tag', 'gene', 'product', 'source', 'source_id', 'description',
                                        'e_value', 'evidence'],
                            protein_structure => ['pdb_id', 'title', 'organism_name', 'patric_id', 'uniprotkb_accession',
                                        'gene', 'product', 'method', 'release_date'],
                            surveillance => ['sample_identifier', 'sample_material', 'collector_institution', 'collection_year',
                                             'collection_country', 'pathogen_test_type', 'pathogen_test_result'. 'type',
                                             'subtype', 'strain', 'host_identifier', 'host_species', 'host_common_name',
                                             'host_age', 'host_health'],
                            serology => ['sample_identifier', 'host_identifier', 'host_type', 'host_species', 'host_common_name',
                                            'host_sex', 'host_age', 'host_age_group', 'host_health', 'collection_date', 'test_type', 'test_result',
                                            'serotype'],
                            sf => ['sf_id', 'sf_name', 'sf_category', 'gene', 'length', 'sf_category', 'start', 'end', 'source_strain' ],
                            sfvt => ['sf_id', 'sf_name', 'sf_category', 'sfvt_id', 'sfvt_genome_count', 'sfvt_sequence'],
};

=head3 IDCOL

Mapping from user-friendly object names to ID column names.

=cut

use constant IDCOL =>   {   genome => 'genome_id',
                            feature => 'patric_id',
                            alt_feature => 'feature_id',
                            family => 'family_id',
                            genome_drug => 'id',
                            contig => 'sequence_id',
                            drug => 'antibiotic_name',
                            experiment => 'eid',
                            sample => 'expid',
                            expression => 'id',
                            taxonomy => 'taxon_id',
                            sequence => 'md5',
                            sp_gene => 'patric_id',
                            subsystem => 'subsystem_id',
                            subsystemItem => 'id',
                            protein_region => 'id',
                            protein_structure => 'pdb_id',
                            surveillance => 'sample_identifier',
                            serology => 'sample_identifier',
                            sf => 'sf_id',
                            sfvt => 'id'
                        };

=head3 DERIVED

Mapping from objects to derived fields. For each derived field name we have a list reference consisting of the function name followed by a list of the
constituent fields.

=cut

use constant DERIVED => {
            genome =>   {   taxonomy => ['concatSemi', 'taxon_lineage_names'],
                        },
            feature =>  {   function => ['altName', 'product'],
                            ec => ['ecParse', 'product']
                        },
            alt_feature => {   function => ['altName', 'product'],
                            ec => ['ecParse', 'product']
                        },
            family =>   {
                        },
            genome_drug => {
                        },
            contig =>   {   md5 => ['md5', 'sequence'],
                        },
            drug =>     {
                        },
            experiment => {
                        },
            sample =>   {
                        },
            expression => {
                        },
            subsystem => {
                        },
            subsystemItem => {
                        },
            protein_region => {
                        },
            protein_structure => {
                        },
            surveillance => {
                        },
            serology => {
                        },

};

use constant DERIVED_MULTI => {
            genome =>   {
                        },
            feature =>  {   ec => 1,
                            subsystem => 1,
                            pathway => 1
                        },
            alt_feature => { ec => 1,
                            subsystem => 1,
                            pathway => 1
                        },
            genome_drug => {
                        },
            contig =>   {
                        },
            drug =>     {
                        },
            experiment => {
                        },
            sample =>   {
                        },
            expression => {
                        },
            subsystem => {
                        },
            subsystemItem => {
                        },
            protein_region => {
                        },
            protein_structure => {
                        },
            surveillance => {
                        },
            serology => {
                        },

};

=head3 RELATED

Mapping from objects to fields in related records. For each related field we have a list reference consisting of the key field name, the
target table, the target table key, and the target field.

=cut

use constant RELATED => {
        feature =>  {   na_sequence => ['na_sequence_md5', 'feature_sequence', 'md5', 'sequence'],
                        aa_sequence => ['aa_sequence_md5', 'feature_sequence', 'md5', 'sequence'],
                        pathway => ['patric_id', 'pathway', 'patric_id', 'pathway_name'],
                        subsystem => ['patric_id', 'subsystem', 'patric_id', 'subsystem_name']
        },
        alt_feature => { na_sequence => ['na_sequence_md5', 'feature_sequence', 'md5', 'sequence'],
                        aa_sequence => ['aa_sequence_md5', 'feature_sequence', 'md5', 'sequence'],
                        pathway => ['patric_id', 'pathway', 'patric_id', 'pathway_name'],
                        subsystem => ['patric_id', 'subsystem', 'patric_id', 'subsystem_name']
        },
        genome => 	{	genetic_code => ['taxon_id', 'taxonomy', 'taxon_id', 'genetic_code'] },
        protein =>  {   aa_sequence => ['aa_sequence_md5', 'feature_sequence', 'md5', 'sequence'] },
};


=head2  Methods

=head3 data_options

    my @opts = P3Utils::data_options();

This method returns a list of the L<Getopt::Long::Descriptive> specifications for the common data retrieval
options. These options include L</delim_options> plus the following.

=over 4

=item attr

Names of the fields to return. Multiple field names may be specified by coding the option multiple times or
separating the field names with commas.  Mutually exclusive with C<--count>.

=item count

If specified, a count of records found will be returned instead of the records themselves. Mutually exclusive with C<--attr>.

=item equal

Equality constraints of the form I<field-name>C<,>I<value>. If the field is numeric, the constraint will be an
exact match. If the field is a string, the constraint will be a substring match. An asterisk in string values
is interpreted as a wild card. Multiple equality constraints may be specified by coding the option multiple
times.

=item lt, le, gt, ge, ne

Inequality constraints of the form I<field-name>C<,>I<value>. Multiple constrains of each type may be specified
by coding the option multiple times.

=item in

Multi-valued equality constraints of the form I<field-name>C<,>I<value1>C<,>I<value2>C<,>I<...>C<,>I<valueN>.
The constraint is satisfied if the field value matches any one of the specified constraint values. Multiple
constraints may be specified by coding the option multiple times.

=item required

Specifies the name of a field that must have a value for the record to be included in the output. Multiple
fields may be specified by coding the option multiple times.

=item keyword

Specifies a keyword or phrase (in quotes) that should be included in any field of the output. This performs a
text search against entire records.

=item debug

Display debugging information on STDERR.

=item limit

Specify the maximum number of records to return. (The default is all records.) This is the maximum returned from
the database, for performance reasons. The number of records actually returned may be substantially lower.

=item view

Specify the name of a L<P3View> file to use for translating field names.

=back

=cut

sub data_options {
    return (['attr|a=s@', 'field(s) to return'],
            ['count|K', 'if specified, a count of records returned will be displayed instead of the records themselves'],
            ['equal|eq|e=s@', 'search constraint(s) in the form field_name,value'],
            ['lt=s@', 'less-than search constraint(s) in the form field_name,value'],
            ['le=s@', 'less-or-equal search constraint(s) in the form field_name,value'],
            ['gt=s@', 'greater-than search constraint(s) in the form field_name,value'],
            ['ge=s@', 'greater-or-equal search constraint(s) in the form field_name,value'],
            ['ne=s@', 'not-equal search constraint(s) in the form field_name,value'],
            ['in=s@', 'any-value search constraint(s) in the form field_name,value1,value2,...,valueN'],
            ['keyword=s', 'if specified, a keyword or phrase that shoould be in at least one field of every record'],
            ['required|r=s@', 'field(s) required to have values'],
            ['debug', 'display debugging on STDERR'],
            ['limit=i', 'maximum number of results to return'],
            ['view=s', 'name of P3View file to use for translating field names'],
            delim_options());
}

=head3 col_options

    my @opts = P3Utils::col_options($batchSize);

This method returns a list of the L<Getopt::Long::Descriptive> specifications for the common column specification
options. These options are as follows.

=over 4

=item col

Index (1-based) of the column number to contain the key field. If a non-numeric value is specified, it is presumed
to be the value of the header in the desired column. The default is C<0>, which indicates the last column.

=item batchSize

Maximum number of lines to read in a batch. The default is C<100>.

=item nohead

Input file has no headers.

=back

The method takes as a parameter a default batch size to override the normal
default of 100.

=cut

sub col_options {
    my ($batchSize) = @_;
    $batchSize //= 100;
    return (['col|c=s', 'column number (1-based) or name', { default => 0 }],
                ['batchSize|b=i', 'input batch size', { default => $batchSize }],
                ['nohead', 'file has no headers']);
}

=head3 delim_options

    my @options = P3Utils::delim_options();

This method returns a list of options related to delimiter specification for multi-valued fields.

=over 4

=item delim

The delimiter to use between object names. The default is C<::>. Specify C<tab> for tab-delimited output, C<space> for
space-delimited output, C<semi> for a semicolon followed by a space, or C<comma> for comma-delimited output.
Other values might have unexpected results.

=back

=cut

sub delim_options {
    return (['delim=s', 'delimiter to place between object names', { default => '::' }],
    );
}

=head3 delim

    my $delim = P3Utils::delim($opt);

Return the delimiter to use between the elements of multi-valued fields.

=over 4

=item opt

A L<Getopts::Long::Descriptive::Opts> object containing the delimiter specification.

=back

=cut

use constant DELIMS => { space => ' ', tab => "\t", comma => ',', '::' => '::', semi => '; ' };

sub delim {
    my ($opt) = @_;
    my $retVal = DELIMS->{$opt->delim} // $opt->delim;
    return $retVal;
}

=head3 undelim

    my $undelim = P3Utils::undelim($opt);

Return the pattern to use to split the elements of multi-valued fields.

=over 4

=item opt

A L<Getopts::Long::Descriptive::Opts> object containing the delimiter specification.

=back

=cut

use constant UNDELIMS => { space => ' ', tab => '\t', comma => ',', '::' => '::', semi => '; ' };

sub undelim {
    my ($opt) = @_;
    my $retVal = UNDELIMS->{$opt->delim} // $opt->delim;
    return $retVal;
}

=head3 get_couplets

    my $couplets = P3Utils::get_couplets($ih, $colNum, $opt);

Read a chunk of data from a tab-delimited input file and return couplets. A couplet is a 2-tuple consisting of a
key column followed by a reference to a list containing all the columns. The maximum number of couplets returned
is determined by the batch size. If the input file is empty, an undefined value will be returned.

=over 4

=item ih

Open input file handle for the tab-delimited input file.

=item colNum

Index of the key column.

=item opt

A L<Getopts::Long::Descriptive::Opts> object containing the batch size specification.

=item RETURN

Returns a reference to a list of couplets.

=back

=cut

sub get_couplets {
    my ($ih, $colNum, $opt) = @_;
    # Declare the return variable.
    my $retVal;
    # Only proceed if we are not at end-of-file.
    if (! eof $ih) {
        # Compute the batch size.
        my $batchSize = $opt->batchsize;
        # Initialize the return value to an empty list.
        $retVal = [];
        # This will count the records kept.
        my $count = 0;
        # Loop through the input.
        while (! eof $ih && $count < $batchSize) {
            # Read the next line.
            my $line = <$ih>;
            # Split the line into fields.
            my @fields = get_fields($line);
            # Extract the key column.
            my $key = $fields[$colNum];
            # Store the couplet.
            push @$retVal, [$key, \@fields];
            # Count this record.
            $count++;
        }
    }
    # Return the result.
    return $retVal;
}

=head3 get_col

    my $column = P3Utils::get_col($ih, $colNum);

Read an entire column of data from a tab-delimited input file.

=over 4

=item ih

Open input file handle for the tab-delimited input file, positioned after the headers.

=item colNum

Index of the key column.

=item RETURN

Returns a reference to a list of column values.

=back

=cut

sub get_col {
    my ($ih, $colNum) = @_;
    # Declare the return variable.
    my @retVal;
    # Loop through the input.
    while (! eof $ih) {
        # Read the next line.
        my $line = <$ih>;
        # Split the line into fields.
        my @fields = get_fields($line);
        # Extract the key column.
        push @retVal, $fields[$colNum];
    }
    # Return the result.
    return \@retVal;
}

=head3 process_headers

    my ($outHeaders, $keyCol) = P3Utils::process_headers($ih, $opt, $keyless);

Read the header line from a tab-delimited input, format the output headers and compute the index of the key column.
Note that this entire process is performed on untranslated (pre-view) field names. The key column is specified
by a parameter in the options, so it is also untranslated.

=over 4

=item ih

Open input file handle.

=item opt

Should be a L<Getopts::Long::Descriptive::Opts> object containing the specifications for the key
column or a string containing the key column name. At a minimum, it must support the C<nohead> option.

=item keyless (optional)

If TRUE, then it is presumed there is no key column.

=item RETURN

Returns a two-element list consisting of a reference to a list of the header values and the 0-based index of the key
column. If there is no key column, the second element of the list will be undefined.

=back

=cut

sub process_headers {
    my ($ih, $opt, $keyless) = @_;
    # Read the header line.
    my $line;
    if ($opt->nohead) {
        $line = '';
    } else {
        $line = <$ih>;
        die "Input file is empty.\n" if (! defined $line);
    }
    # Split the line into fields.
    my @outHeaders = get_fields($line);
    # This will contain the key column number.
    my $keyCol;
    # Search for the key column.
    if (! $keyless) {
        $keyCol = find_column($opt->col, \@outHeaders);
    }
    # Return the results.
    return (\@outHeaders, $keyCol);
}

=head3 find_column

    my $keyCol = P3Utils::find_column($col, \@headers, $optional);

Determine the correct (0-based) index of the key column in a file from a column specifier and the headers.
The column specifier can be a 1-based index or the name of a header. Since the header is always untranslated
(pre-view), the key column name must be, too.

=over 4

=item col

Incoming column specifier.

=item headers

Reference to a list of column header names.

=item optional (optional)

If TRUE, then failure to find the header is not an error.

=item RETURN

Returns the 0-based index of the key column or C<undef> if the header was not found.

=back

=cut

sub find_column {
    my ($col, $headers, $optional) = @_;
    my $retVal;
    if ($col =~ /^\-?\d+$/) {
        # Here we have a column number.
        $retVal = $col - 1;
    } else {
        # Here we have a header name.
        my $n = scalar @$headers;
        for ($retVal = 0; $retVal < $n && $headers->[$retVal] ne $col; $retVal++) {};
        # If our quick search failed, check for a match past the dot.
        if ($retVal >= $n) {
            undef $retVal;
            for (my $i = 0; $i < $n && ! $retVal; $i++) {
                if ($headers->[$i] =~ /\.(.+)$/ && $1 eq $col) {
                    $retVal = $i;
                }
            }
            if (! defined $retVal && ! $optional) {
                die "\"$col\" not found in headers.";
            }
        }
    }
    return $retVal;

}

=head3 form_filter

    my $filterList = P3Utils::form_filter($p3, $opt);

Compute the filter list for the specified options. Note that the options specify untranslated (pre-view) column names,
but the filter must be built using translated (internal) column names.

=over 4

=item p3

A L<P3DataAPI> object used to access PATRIC. This is used to apply the P3View, if any.

=item opt

A L<Getopt::Long::Descriptive::Opts> object containing the command-line options that constrain the query (C<--equal>, C<--in>).

=item RETURN

Returns a reference to a list of filter specifications for a call to L<P3DataAPI/query>.

=back

=cut

sub form_filter {
    my ($p3, $opt) = @_;
    # This will be the return list.
    my @retVal;
    # Get the relational operator constraints.
    my %opHash = ('eq' => ($opt->equal // []),
                  'lt' => ($opt->lt // []),
                  'le' => ($opt->le // []),
                  'gt' => ($opt->gt // []),
                  'ge' => ($opt->ge // []),
                  'ne' => ($opt->ne // []));
    # Loop through them.
    for my $op (keys %opHash) {
        for my $opSpec (@{$opHash{$op}}) {
            # Get the field name and value.
            my ($field, $value);
            if ($opSpec =~ /(\w+),(.+)/) {
                ($field, $value) = ($1, clean_value($2));
            } else {
                die "Invalid --$op specification $opSpec.";
            }
            # Convert the field name to internal format.
            my $internalField = $p3->{view}->col_to_internal($field);
            # Apply the constraint.
            push @retVal, [$op, $internalField, $value];
        }
    }
    # Get the inclusion constraints.
    my $inList = $opt->in // [];
    for my $inSpec (@$inList) {
        # Get the field name and values.
        my ($field, @values) = split /,/, $inSpec;
        # Validate the field name.
        die "Invalid field name \"$field\" for in-specification." if ($field =~ /\W/);
        # Clean the values.
        @values = map { clean_value($_) } @values;
        # Apply the constraint.
        push @retVal, ['in', $field, '(' . join(',', @values) . ')'];
    }
    # Get the requirement constraints.
    my $reqList = $opt->required // [];
    for my $field (@$reqList) {
        # Validate the field name.
        die "Invalid field name \"$field\" for required-specification." if ($field =~ /\W+/);
        # Apply the constraint.
        push @retVal, ['eq', $field, '*'];
    }
    # Check for a keyword constraint.
    my $keyword = $opt->keyword;
    if ($keyword) {
        # Apply the constraint.
        push @retVal, ['keyword', $keyword];
    }
    # Return the filter clauses.
    return \@retVal;
}

=head3 select_clause

    my ($selectList, $newHeaders) = P3Utils::select_clause($p3, $object, $opt, $idFlag, \@default);

Determine the list of fields to be returned for the current query. If an C<--attr> option is present, its
listed fields are used. Otherwise, a default list is used. The default list is translated (internal names),
but an explicit attribute list from the command-line options will be pre-view (untranslated names) and
must be translated to form the select clause.

=over 4

=item p3

The L<P3DataAPI> object used to access PATRIC.

=item object

Name of the object being retrieved-- C<genome>, C<feature>, C<protein_family>, or C<genome_drug>.

=item opt

L<Getopt::Long::Descriptive::Opts> object for the command-line options, including the C<--attr> option.

=item idFlag

If TRUE, then only the ID column will be specified if no attributes are explicitly specified. and if attributes are
explicitly specified, the ID column will be added if it is not present.

=item default

If specified, must be a reference to a list of field names.  The named fields will be returned if no C<--attr> option
is passed in.  This overrides the normal default fields.

=item RETURN

Returns a two-element list consisting of a reference to a list of the names of the
fields to retrieve, and a reference to a list of the proposed headers for the new columns. If the user wants a
count, the first element will be undefined, and the second will be a singleton list of C<count>.

=back

=cut

sub select_clause {
    my ($p3, $object, $opt, $idFlag, $default) = @_;
    # Validate the object.
    my $realName = OBJECTS->{$object};
    die "Invalid object $object." if (! $realName);
    # Here we need to load the P3View if there is one specified. If not, a null view is attached to the $p3
    # automatically.
    $p3->{view} = P3View->new($opt->view, $object);
    # Get the attribute option.
    my $attrList = $opt->attr;
    if ($opt->count) {
        # Here the user wants a count, not data.
        if ($attrList) {
            die "Cannot specify both --attr and --count.";
        } else {
            # Just return a count header.
            $attrList = ['count'];
        }
    } else {
        if (! $attrList) {
            if ($idFlag) {
                $attrList = [IDCOL->{$object}];
            } elsif ($default) {
                $attrList = $default;
            } else {
                $attrList = FIELDS->{$object};
            }
            # Un-translate this attribute list so it is in pre-view format.
            $attrList = $p3->{view}->internal_list_to_col($attrList);
        } else {
            # Compute the pre-view (untranslated) version of the ID field.
            my $idCol = $p3->{view}->col_to_internal(IDCOL->{$object});      
            # Handle comma-splicing.
            $attrList = [ map { split /,/, $_ } @$attrList ];
            # If we need an ID field, be sure it's in there.
            if ($idFlag) {
                if (! scalar(grep { $_ eq $idCol } @$attrList)) {
                    unshift @$attrList, $idCol;
                }
            }
        }
    }
    # Form the header list.
    my @headers = map { "$object.$_" } @$attrList;
    # Clear the attribute list if we are counting.
    if ($opt->count) {
        undef $attrList;
    } else {
        # Translate the attribute list here to internal.
        $attrList = $p3->{view}->col_list_to_internal($attrList);
    }
    # Check for the debug option.
    if ($opt->debug) {
        $p3->debug_on(\*STDERR);
    }
    # Check for a hard limit.
    my $hardLimit = $opt->limit;
    if (defined $hardLimit) {
		$p3->set_limit($hardLimit);
	} else {
		$p3->clear_limit();
	}
    # Return the results.
    return ($attrList, \@headers);
}

=head3 clean_value

    my $cleaned = P3Utils::clean_value($value);

Clean up a value for use in a filter specification.

=over 4

=item value

Value to clean up. Cleaning involves removing parentheses, illegal characters, and leading and
trailing spaces.

=item RETURN

Returns a usable version of the incoming value.

=back

=cut

sub clean_value {
    my ($value) = @_;
    $value =~ tr/()/  /;
    $value =~ s/\s+/ /g;
    $value =~ s/^\s+//;
    $value =~ s/\s+$//;
    $value =~ s/'//;
    if ($value =~ /^[^"].+\s/) {
        $value = "\"$value\"";
    }
    return $value;
}


=head3 get_data

    my $resultList = P3Utils::get_data($p3, $object, \@filter, \@cols, $fieldName, \@couplets);

Return all of the indicated fields for the indicated entity (object) with the specified constraints.
It should be noted that this method is simply a less-general interface to L<P3DataAPI/query> that handles standard
command-line script options for filtering. Everything passed to this method must use internal field names.

=over 4

=item p3

L<P3DataAPI> object for accessing the database.

=item object

User-friendly name of the PATRIC object whose data is desired (e.g. C<genome>, C<genome_feature>).

=item filter

Reference to a list of filter clauses for the query.

=item cols

Reference to a list of the names of the fields to return from the object, or C<undef> if a count is desired.

=item fieldName (optional)

The name of the field in the specified object that is to be used as the key field. If an all-objects query is desired, then
this parameter should be omitted.

=item couplets (optional)

A reference to a list of 2-tuples, each tuple consisting of a key value followed by a reference to a list of the values
from the input row containing that key value.

=item RETURN

Returns a reference to a list of tuples containing the data returned by PATRIC, each output row appended to the appropriate input
row from the couplets.

=back

=cut

sub get_data {
    my ($p3, $object, $filter, $cols, $fieldName, $couplets) = @_;
    # Ths will be the return list.
    my @retVal;
    # Convert the object name.
    my $realName = OBJECTS->{$object};
    my $idCol = IDCOL->{$object};
    # Now we need to form the query modifiers. We start with the column selector. If we're counting, we use the ID column.
    my @selected;
    if (! $cols) {
        @selected = $idCol;
    } else {
        my $computed = _select_list($p3,$object, $cols);
        @selected = @$computed;
    }
    my @mods = (['select', @selected], @$filter);
    # Finally, we loop through the couplets, making calls. If there are no couplets, we make one call with
    # no additional filtering.
    if (! $fieldName) {
        my @entries = $p3->query($realName, @mods);
        _process_entries($p3, $object, \@retVal, \@entries, [], $cols, $idCol);
    } else {
        # Here we need to loop through the couplets one at a time.
        for my $couplet (@$couplets) {
            my ($key, $row) = @$couplet;
            # Verify there are no wild cards in the key value.
            if ($key =~ /\*/) {
                die "Cannot specify a wild card (*) in a key value.";
            }
            # Create the final filter.
            my $keyField = ['eq', $fieldName, clean_value($key)];
            # Make the query.
            my @entries = $p3->query($realName, $keyField, @mods);
            # Process the results.
            _process_entries($p3, $object, \@retVal, \@entries, $row, $cols, $idCol);
        }
    }
    # Return the result rows.
    return \@retVal;
}

=head3 get_data_batch

    my $resultList = P3Utils::get_data_batch($p3, $object, \@filter, \@cols, \@couplets, $keyField);

Return all of the indicated fields for the indicated entity (object) with the specified constraints.
This version differs from L</get_data> in that the couplet keys are matched to a true key field (the
matches are exact).  Everything passed to this method must use internal field names.

=over 4

=item p3

L<P3DataAPI> object for accessing the database.

=item object

User-friendly name of the PATRIC object whose data is desired (e.g. C<genome>, C<feature>).

=item filter

Reference to a list of filter clauses for the query.

=item cols

Reference to a list of the names of the fields to return from the object, or C<undef> if a count is desired.

=item couplets

A reference to a list of 2-tuples, each tuple consisting of a key value followed by a reference to a list of the values
from the input row containing that key value.

=item keyfield (optional)

The key field to use. If omitted, the object's ID field is used.

=item RETURN

Returns a reference to a list of tuples containing the data returned by PATRIC, each output row appended to the appropriate input
row from the couplets.

=back

=cut

sub get_data_batch {
    my ($p3, $object, $filter, $cols, $couplets, $keyField) = @_;
    # Ths will be the return list.
    my @retVal;
    # Get the real object name and the ID column.
    my $realName = OBJECTS->{$object};
    my $idCol = IDCOL->{$object};
    $keyField //= $idCol;
    # Now we need to form the query modifiers. We start with the column selector. We need to insure the key
    # field is included.
    my @keyList;
    if (! scalar(grep { $_ eq $keyField } @$cols)) {
        @keyList = ($keyField);
    }
    my $computed = _select_list($p3, $object, $cols);
    my @mods = (['select', @keyList, @$computed], @$filter);
    # Now get the list of key values. These are not cleaned, because we are doing exact matches.
    my @keys = grep { $_ ne '' } map { clean_value($_->[0]) } @$couplets;
    # Only proceed if we have at least one key.
    if (scalar @keys) {
        # Insure there are no wildcards in the keys.
        if (grep { $_ =~ /\*/ } @keys) {
            die "No wildcards (*) allowed in key fields.";
        }
        # Create a filter for the keys.
        my $keyClause = [in => $keyField, '(' . join(',', @keys) . ')'];
        # Next we run the query and process it into rows.
        my $results = [ $p3->query($realName, $keyClause, @mods) ];
        my $entries = [];
        _process_entries($p3, $object, $entries, $results, [], $cols, $idCol, $keyField);
        # Remove the results to save space.
        undef $results;
        # Convert the entries into a hash.
        my %entries;
        for my $result (@$entries) {
            my ($keyValue, @data) = @$result;
            push @{$entries{$keyValue}}, \@data;
        }
        # Empty the entries array to save memory.
        undef $entries;
        # Now loop through the couplets, producing output.
        for my $couplet (@$couplets) {
            my ($key, $row) = @$couplet;
            my $entryList = $entries{$key};
            if ($entryList) {
                for my $entry (@$entryList) {
                    push @retVal, [@$row, @$entry];
                }
            }
        }
    }
    # Return the result rows.
    return \@retVal;
}

=head3 get_data_keyed

    my $resultList = P3Utils::get_data_keyed($p3, $object, \@filter, \@cols, \@keys, $keyField);

Return all of the indicated fields for the indicated entity (object) with the specified constraints.
The query is by key, and the keys are split into batches to prevent PATRIC from overloading.
Everything passed to this method must use internal field names.

=over 4

=item p3

L<P3DataAPI> object for accessing the database.

=item object

User-friendly name of the PATRIC object whose data is desired (e.g. C<genome>, C<feature>).

=item filter

Reference to a list of filter clauses for the query.

=item cols

Reference to a list of the names of the fields to return from the object, or C<undef> if a count is desired.

=item keys

A reference to a list of key values.

=item keyfield (optional)

The key field to use. If omitted, the object's ID field is used.

=item RETURN

Returns a reference to a list of tuples containing the data returned by PATRIC.

=back

=cut

sub get_data_keyed {
    my ($p3, $object, $filter, $cols, $keys, $keyField) = @_;
    # Ths will be the return list.
    my @retVal;
    # Get the real object name and the ID column.
    my $realName = OBJECTS->{$object};
    my $idCol = IDCOL->{$object};
    $keyField //= $idCol;
    # Now we need to form the query modifiers. We start with the column selector. We need to insure the key
    # field is included.
    my @keyList;
    if (! scalar(grep { $_ eq $keyField } @$cols)) {
        @keyList = ($keyField);
    }
    my $computed = _select_list($p3, $object, $cols);
    my @mods = (['select', @keyList, @$computed], @$filter);
    # Verify there are no wild cards in the keys.
    if (grep { $_ =~ /\*/ } @$keys) {
        die "Cannot specify a wild card (*) in a key value.";
    }
    # Create a filter for the keys.  We loop through the keys, a group at a time.
    my $n = @$keys;
    for (my $i = 0; $i < @$keys; $i += 200) {
        # Split out the keys in this batch.
        my $j = $i + 199;
        if ($j >= $n) { $j = $n - 1 };
        my @keys = @{$keys}[$i .. $j];
        my $keyClause = [in => $keyField, '(' . join(',', @keys) . ')'];
        # Next we run the query and push the output into the return list.
        my @results = $p3->query($realName, $keyClause, @mods);
        _process_entries($p3, $object, \@retVal, \@results, [], $cols, $idCol);
    }
    # Return the result rows.
    return \@retVal;
}

=head3 script_opts

    my $opt = P3Utils::script_opts($parmComment, @options);

Process the command-line options for a P3 script. This method automatically handles the C<--help> option.

=over 4

=item parmComment

A string indicating the command's signature for the positional parameters. Used for the help display.

=item options

A list of options such as are expected by L<Getopt::Long::Descriptive>.

=item RETURN

Returns the options object. Every command-line option's value may be retrieved using a method
on this object.

If invoked in array context, returns the options object, usage object pair so that
the calling code may emit detailed usage messages if needed.

=back

=cut

sub script_opts {
    # Get the parameters.
    my ($parmComment, @options) = @_;
    # Insure we can talk to PATRIC from inside Argonne.
    $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
    # Parse the command line.
    my ($retVal, $usage) = describe_options('%c %o ' . $parmComment, @options,
           [ "help|h", "display usage information", { shortcircuit => 1}]);
    # The above method dies if the options are invalid. We check here for the HELP option.
    if ($retVal->help) {
        print $usage->text;
        exit;
    }
    return wantarray ? ($retVal, $usage) : $retVal;
}

=head3 print_cols

    P3Utils::print_cols(\@cols, %options);

Print a tab-delimited output row.

=over 4

=item cols

Reference to a list of the values to appear in the output row.

=item options

A hash of options, including zero or more of the following.

=over 8

=item oh

Open file handle for the output stream. The default is \*STDOUT.

=item opt

A L<Getopt::Long::Descriptive::Opts> object containing the delimiter option, for computing the delimiter in multi-valued fields.

=item delim

The delimiter to use in multi-valued fields (overrides C<opt>). The default, if neither this nor C<opt> is specified, is a comma (C<,>).

=back

=back

=cut

sub print_cols {
    my ($cols, %options) = @_;
    # Compute the options.
    my $oh = $options{oh} || \*STDOUT;
    my $opt = $options{opt};
    my $delim = $options{delim};
    if (! defined $delim) {
        if (defined $opt && $opt->delim) {
            $delim = P3Utils::delim($opt);
        } else {
            $delim = ',';
        }
    }
    # Loop through the columns, formatting.
    my @r;
    for my $r (@$cols) {
        if (! defined $r) {
            push(@r, '')
        } elsif (ref($r) eq "ARRAY") {
            my $a = join($delim, @{$r});
            push(@r, $a);
        } else {
            push(@r, $r);
        }
    }
    # Print the columns.
    print $oh join("\t", @r) . "\n";
}


=head3 ih

    my $ih = P3Utils::ih($opt);

Get the input file handle from the options. If no input file is specified in the options,
opens the standard input.

=over 4

=item opt

L<Getopt::Long::Descriptive::Opts> object for the current command-line options.

=item RETURN

Returns an open file handle for the script input.

=back

=cut

sub ih {
    # Get the parameters.
    my ($opt) = @_;
    # Declare the return variable.
    my $retVal;
    # Get the input file name.
    my $fileName = $opt->input;
    # Check for a value.
    if (! $fileName) {
        # Here we have the standard input.
        $retVal = \*STDIN;
    } else {
        # Here we have a real file name.
        open($retVal, "<$fileName") ||
            die "Could not open input file $fileName: $!";
    }
    # Return the open handle.
    return $retVal;
}


=head3 ih_options

    my @opt_specs = P3Utils::ih_options();

These are the command-line options for specifying a standard input file.

=over 4

=item input

Name of the main input file. If omitted and an input file is required, the standard
input is used.

=back

=cut

sub ih_options {
    return (
            ["input|i=s", "name of the input file (if not the standard input)"]
    );
}

=head3 oh

    my $oh = P3Utils::oh($opt);

Get the output file handle from the options. If no output file is specified in the options,
opens the standard output.

=over 4

=item opt

L<Getopt::Long::Descriptive::Opts> object for the current command-line options.

=item RETURN

Returns an open file handle for the script output.

=back

=cut

sub oh {
    # Get the parameters.
    my ($opt) = @_;
    # Declare the return variable.
    my $retVal;
    # Get the input file name.
    my $fileName = $opt->output;
    # Check for a value.
    if (! $fileName) {
        # Here we have the standard output.
        $retVal = \*STDOUT;
    } else {
        # Here we have a real file name.
        open($retVal, ">$fileName") ||
            die "Could not open output file $fileName: $!";
    }
    # Return the open handle.
    return $retVal;
}


=head3 oh_options

    my @opt_specs = P3Utils::oh_options();

These are the command-line options for specifying a standard output file.

=over 4

=item output

Name of the main output file. If omitted and an input file is required, the standard
output is used.

=back

=cut

sub oh_options {
    return (
            ["output|o=s", "name of the output file (if not the standard output)"]
    );
}

=head3 match

    my $flag = P3Utils::match($pattern, $key, %options);

Test a match pattern against a key value and return C<1> if there is a match and C<0> otherwise.
If the key is numeric, a numeric equality match is performed. If the key is non-numeric, then
we have a match if any subsequence of the words in the key is equal to the pattern (case-insensitive).
The goal here is to more or less replicate the SOLR B<eq> operator.

=over 4

=item pattern

The pattern to be matched.  If C<undef>, then any nonblank key matches.

=item key

The value against which to match the pattern.

=item options

Zero or more of the following keys, which modify the match.

=over 8

=item exact

If TRUE, then non-numeric matches are exact.

=back

=item RETURN

Returns C<1> if there is a match, else C<0>.

=back

=cut

sub match {
    my ($pattern, $key, %options) = @_;
    # This will be the return value.
    my $retVal = 0;
    # Determine the type of match.
    if (! defined $pattern) {
        # Here we have a nonblank match.
        if (defined $key && $key =~ /\S/) {
            $retVal = 1;
        }
    } elsif ($pattern =~ /^\-?\d+(?:\.\d+)?$/) {
        # Here we have a numeric match.
        if ($key =~ /^\-?\d+(?:\.\d+)?$/ && $pattern == $key) {
            $retVal = 1;
        }
    } elsif ($options{exact}) {
        # Here we have an exact match.
        if ($pattern eq $key) {
            $retVal = 1;
        }
    } else {
        # Here we have a substring match.
        my @patternI = split ' ', lc $pattern;
        my @keyI = split ' ', lc $key;
        for (my $i = 0; ! $retVal && $i < scalar @keyI; $i++) {
            if ($patternI[0] eq $keyI[$i]) {
                my $possible = 1;
                for (my $j = 1; $possible && $j < scalar @patternI; $j++) {
                    if ($patternI[$j] ne $keyI[$i+$j]) {
                        $possible = 0;
                    }
                }
                $retVal = $possible;
            }
        }
    }
    # Return the determination indicator.
    return $retVal;
}

=head3 protein_fasta

    P3Utils::protein_fasta($p3, $genome, $fileName);

Create a FASTA file for the proteins in a genome.

=over 4

=item p3

A L<P3DataAPI> object for downloading from PATRIC.

=item genome

The ID of the genome whose proteins are desired.

=item fileName

The name of a file to contain the FASTA data, or an open output file handle to which the data should be written.

=back

=cut

sub protein_fasta {
    my ($p3, $genome, $fileName) = @_;
    # Get the output handle.
    my $oh;
    if (ref $fileName eq 'GLOB') {
        $oh = $fileName;
    } else {
        open($oh, '>', $fileName) || die "Could not open $fileName: $!";
    }
    my $triples = P3Utils::get_data($p3, 'feature', [['eq', 'genome_id', $genome], ['eq', 'feature_type', 'CDS']],
            ['patric_id', 'product', 'aa_sequence']);
    for my $triple (@$triples) {
        my ($id, $comment, $seq) = @$triple;
        if ($id =~ /^fig/ && $comment && $seq) {
            print $oh ">$id $comment\n$seq\n";
        }
    }
}

=head3 find_headers

    my (\@headers, \@cols) = P3Utils::find_headers($ih, $fileType => @fields);

Search the headers of the specified input file for the named fields and return the list of headers plus a list of
the column indices for the named fields. Since this method deals with headers, all the field names are untranslated
(that is, pre-view, not internal).

=over 4

=item ih

Open input file handle, or a reference to a list of headers.

=item fileType

Name to give the input file in error messages.

=item fields

A list of field names for the desired columns.

=item RETURN

Returns a two-element list consisting of (0) a reference to a list of the headers from the input file and
(1) a reference to a list of column indices for the desired columns of the input, in order.

=back

=cut

sub find_headers {
    my ($ih, $fileType, @fields) = @_;
    # Read the column headers from the file.
    my @headers;
    if (ref $ih eq 'ARRAY') {
        @headers = @$ih;
    } else {
        my $line = <$ih>;
        @headers = get_fields($line);
    }
    # Get a hash of the field names.
    my %fieldH = map { $_ => undef } @fields;
    # Loop through the headers, saving indices.
    for (my $i = 0; $i < @headers; $i++) {
        my $header = $headers[$i];
        if (exists $fieldH{$header}) {
            $fieldH{$header} = $i;
        }
    }
    # Now one more time, looking for abbreviated header names.
    for (my $i = 0; $i < @headers; $i++) {
        my @headers = split /\./, $headers[$i];
        my $header = pop @headers;
        if (exists $fieldH{$header} && ! defined $fieldH{$header}) {
            $fieldH{$header} = $i;
        }
    }
    # Accumulate the headers that were not found. We also handle numeric column indices in here.
    my @bad;
    for my $field (keys %fieldH) {
        if (! defined $fieldH{$field}) {
            # Is this a number?
            if ($field =~ /^\d+$/) {
                # Yes, convert it to an index.
                $fieldH{$field} = $field - 1;
            } else {
                # No, we have a bad header.
                push @bad, $field;
            }
        }
    }
    # If any headers were not found, it is an error.
    if (scalar(@bad) == 1) {
        die "Could not find required column \"$bad[0]\" in $fileType file.";
    } elsif (scalar(@bad) > 1) {
        die "Could not find required columns in $fileType file: " . join(", ", @bad);
    }
    # If we got this far, we are ok, so return the results.
    my @cols = map { $fieldH{$_} } @fields;
    return (\@headers, \@cols);
}

=head3 get_cols

    my @values = P3Utils::get_cols($ih, $cols);

This method returns all the values in the specified columns of the next line of the input file, in order. It is meant to be used
as a companion to L</find_headers>. A list reference can be used in place of an open file handle, in which case the columns will
be used to index into the list.

=over 4

=item ih

Open input file handle, or alternatively a list reference.

=item cols

Reference to a list of column indices.

=item RETURN

Returns a list containing the fields in the specified columns, in order.

=back

=cut

sub get_cols {
    my ($ih, $cols) = @_;
    # Get the list of field values according to the input type.
    my @fields;
    if (ref $ih eq 'ARRAY') {
        @fields = @$ih;
    } else {
        # Get the columns.
        @fields = get_fields($ih);
    }
    # Extract the ones we want.
    my @retVal = map { $fields[$_] } @$cols;
    # Return the resulting values.
    return @retVal;
}

=head3 get_fields

    my @fields = P3Utils::get_fields($line);

Split a tab-delimited line into fields.

=over 4

=item line

Input line to split, or an open file handle from which to get the next line.

=item RETURN

Returns a list of the fields in the line.

=back

=cut

sub get_fields {
    my ($line) = @_;
    # Read the file, if any.
    if (ref $line eq 'GLOB') {
        $line = <$line>;
    }
    # Split the line.
    my @retVal = split /\t/, $line;
    # Remove the EOL.
    if (@retVal) {
        $retVal[$#retVal] =~ s/[\r\n]+$//;
    }
    # Return the fields.
    return @retVal;
}

=head3 list_object_fields

    my $fieldList = P3Utils::list_object_fields($p3, $object);

Return the list of field names for an object. The database schema is queried directly.

=over 4

=item p3

The L<P3DataAPI> object for accessing PATRIC.

=item object

The name of the object whose field names are desired.

=item RETURN

Returns a reference to a list of the field names.

=back

=cut

sub list_object_fields {
    my ($p3, $object) = @_;
    my @retVal;
    # Get the real name of the object.
    my $realName = OBJECTS->{$object};
    # Ask for the JSON schema string.
    my $ua = LWP::UserAgent->new();
    my $url = $p3->{url} . "/$realName/schema?http_content-type=application/solrquery+x-www-form-urlencoded&http_accept=application/solr+json";
    my $request = HTTP::Request->new(GET => $url);
    my $response = $ua->request($request);
    if ($response->code ne 200) {
        die "Error response from PATRIC: " . $response->message;
    } else {
        my $json = $response->content;
        my $schema = SeedUtils::read_encoded_object(\$json);
        for my $field (@{$schema->{schema}{fields}}) {
            my $string = $field->{name};
            if ($field->{multiValued}) {
                $string .= ' (multi)';
            }
            push @retVal, $string;
        }
        # Get the derived fields.
        my $derivedH = DERIVED->{$object};
        my $multiH = DERIVED_MULTI->{$object};
        for my $field (keys %$derivedH) {
            if ($multiH->{$field}) {
                push @retVal, "$field (derived) (multi)";
            } else {
                push @retVal, "$field (derived)";
            }
        }
        # Get the related fields.
        $derivedH = RELATED->{$object};
        for my $field (keys %$derivedH) {
            if ($multiH->{$field}) {
                push @retVal, "$field (related) (multi)";
            } else {
                push @retVal, "$field (related)";
            }
        }
    }
    # Return the list.
    return [sort @retVal];
}

=head2 Internal Methods

=head3 _process_entries

    P3Utils::_process_entries($p3, $object, \@retList, \@entries, \@row, \@cols, $id, $keyField);

Process the specified results from a PATRIC query and store them in the output list. It's worth
noting that the column name list will have internal column names.

=over 4

=item p3

The L<P3DataAPI> object for querying derived fields.

=item object

Name of the object queried.

=item retList

Reference to a list into which the output rows should be pushed.

=item entries

Reference to a list of query results from PATRIC.

=item row

Reference to a list of values to be prefixed to every output row.

=item cols

Reference to a list of the names of the columns to be put in the output row, or C<undef> if the user wants a count.

=item id (optional)

Name of an ID field that should not be zero or empty. This is used to filter out invalid records.

=item keyField (optional)

Name of an ID field whose value should be put at the beginning of every output row.

=back

=cut

sub _process_entries {
    my ($p3, $object, $retList, $entries, $row, $cols, $id, $keyField) = @_;
    # Are we counting?
    if (! $cols) {
        # Yes. Pop on the count.
        push @$retList, [@$row, scalar grep { $_->{$id} } @$entries];
    } else {
        # No. Generate the data. First we need the related-field hash.
        my $relatedH = RELATED->{$object};
        my $multiH = DERIVED_MULTI->{$object};
        # Now we process the related fields. This is a two-level hash with primary key column name and secondary key input field value
        # that maps each input field value to its target value.
        my %relatedMap;
        for my $col (@$cols) {
            my $algorithm = $relatedH->{$col};
            if ($algorithm) {
                $relatedMap{$col} = _related_field($p3, @$algorithm, $entries, $multiH->{$col});
            }
        }
        # Now we need the derived fields, too.
        my $derivedH = DERIVED->{$object};
        # Loop through the entries.
        for my $entry (@$entries) {
            # Reject the record unless it has real data.
            my $reject = 1;
            # The output columns will be put in here.
            my @outCols;
            # Automatically reject if there is an invalid ID.
            if (! $id || $entry->{$id}) {
                # Loop through the columns to create.
                for my $col (@$cols) {
                    # Get the rule for this column.
                    my @suffix;
                    my $algorithm = $relatedH->{$col};
                    if ($algorithm) {
                        # Related field, found in relatedMap hash.
                        my $value = $entry->{$algorithm->[0]} // '';
                        my $related = $relatedMap{$col}{$value};
                        if (defined $related) {
                            # Keeping this record-- we have a value.
                            $reject = 0;
                        } else {
                            $related = '';
                        }
                        push @outCols, $related;
                    } else {
                        # Here we have a normal or derived field, computed from the values of other fields.
                        $algorithm = $derivedH->{$col} // ['altName', $col];
                        my ($function, @fields) = @$algorithm;
                        my @values = map { $entry->{$_} } @fields;
                        # Verify the values.
                        for (my $i = 0; $i < @values; $i++) {
                            if (! defined $values[$i]) {
                                $values[$i] = '';
                            } else {
                                # Keeping this record-- we have a value.
                                $reject = 0;
                            }
                        }
                        # Now we compute the output value.
                        my $outCol = _apply($function, @values, @suffix);
                        push @outCols, $outCol;
                    }
                }
            }
            # Output the record if it is NOT rejected.
            if (! $reject) {
                my @col0;
                if ($keyField) {
                    @col0 = ($entry->{$keyField});
                }
                push @$retList, [@col0, @$row, @outCols];
            }
        }
    }
}

=head3 _related_field

    my $relatedMap = P3Utils::_related_field($p3, $linkField, $table, $tableKey, $dataField, $entries);

Extract the values for a related field from a list of entries produced by
a query. The link field value is taken from the entry and used to find a
record in a secondary table. The actual desired value for the related
field is taken from the data field in the secondary-table record having
the link field value as key. The return value is a hash mapping link
field values to a data values.

=over 4

=item p3

The L<P3DataAPI> object used to query the database.

=item linkField

The name of the field in the incoming entries containing the key for the secondary table.

=item table

The name of the secondary table containing the actual values.  This is the real SOLR table name.

=item tableKey

The name of the key field to use in the secondary table to find the desired record(s).

=item dataField

The name of the field in the secondary table containing the actual values. This cannot be a derived or related field.

=item entries

A reference to a list of the results from the base query.  Each result is a hash keyed on field name.

=item multi

If TRUE, then the related field will return multiple values.

=item RETURN

Returns a reference to a hash mapping link field values to data field values.

=back

=cut

sub _related_field {
    # Get the parameters.
    my ($p3, $linkField, $table, $tableKey, $dataField, $entries, $multi) = @_;
    # Declare the return variable.
    my %retVal;
    # We need to create a query for the link field values found. The query is limited in size to 2000 characters.
    # These variables accumulate the current query.
    my ($batchSize, @keys) = (0);
    # Now loop through the entries, creating queries.
    for my $entry (@$entries) {
        my $link = $entry->{$linkField};
        if ($link && ! $retVal{$link}) {
            # Here we have a new link field value.
            $batchSize++;
            if ($batchSize >= 200) {
                # The new key would make the query too big. Execute it.
                _execute_query($p3, $table, $tableKey, $dataField, \@keys, \%retVal, $multi);
                $batchSize = 0;
                @keys = ();
            }
            # Now we have room for the new value.
            push @keys, $link;
        }
    }
    # Process the residual.
    if (@keys) {
        _execute_query($p3, $table, $tableKey, $dataField, \@keys, \%retVal, $multi);
    }
    # Return the result.
    return \%retVal;
}

=head3 _execute_query

    P3Utils::_execute_query($p3, $core, $keyField, $dataField, \@keys, \%retHash, $multi);

Execute a query to get the data values associated with a key. The mapping
from keys to data values is added to the specified hash. This method is used for processing
related fields, and uses internal field names for everything.

=over 4

=item p3

The L<P3DataAPI> object for accessing the database.

=item core

The real name of the table containing the data.

=item keyField

The real name of the table's key field.

=item dataField

The real name of the associated data field.

=item keys

A reference to a list of the keys whose data values are desired.

=item multi

If TRUE, then the related field will return multiple values.

=item retHash

A reference to a hash into which results should be placed.

=back

=cut

sub _execute_query {
    # Get the parameters.
    my ($p3, $core, $keyField, $dataField, $keys, $retHash, $multi) = @_;
    # Create the query elements.
    my $select = ['select', $keyField, $dataField];
    my $filter = ['in', $keyField, '(' . join(",", @$keys) . ')'];
    # Execute the query.
    my @entries = $p3->query($core, $select, $filter);
    for my $entry (@entries) {
        if ($multi) {
            push @{$retHash->{$entry->{$keyField}}}, $entry->{$dataField};
        } else {
            $retHash->{$entry->{$keyField}} = $entry->{$dataField};
        }
    }
}


=head3 _apply

    my $result = _apply($function, @values);

Apply a computational function to values to produce a computed field value. This method processes derived
fields, and uses internal field names only.

=over 4

=item function

Name of the function.

=over 8

=item altName

Pass the input value back unmodified.

=item concatSemi

Concatenate the sub-values using a semi-colon/space separator.

=item md5

Compute an MD5 for a DNA or protein sequence.

=back

=item values

List of the input values.

=item RETURN

Returns the computed result.

=back

=cut

sub _apply {
    my ($function, @values) = @_;
    my $retVal;
    if ($function eq 'altName') {
        $retVal = $values[0];
    } elsif ($function eq 'concatSemi') {
        $retVal = join('; ', @{$values[0]});
    } elsif ($function eq 'md5') {
        $retVal = Digest::MD5::md5_hex(uc $values[0]);
    } elsif ($function eq 'ecParse') {
        $retVal = [ _ec_parse($values[0]) ];
    }
    return $retVal;
}

=head3 _ec_parse

    my @ecNums = P3Utils::_ec_parse($product);

Parse the EC numbers out of the functional assignment string of a feature.

=over 4

=item product

The functional assignment string containing the EC numbers.

=item RETURN

Returns a list of EC numbers.

=back

=cut

sub _ec_parse {
    my ($product) = @_;
    my %retVal = map { $_ => 1 } ($product =~ /$RoleParse::EC_PATTERN/g);
    return sort keys %retVal;
}

=head3 _select_list

    my $fieldList = _select_list($p3, $object, $cols);

Compute the list of fields required to retrieve the specified columns. This includes the specified normal fields plus any derived fields.
The input list must contain internal column names.

=over 4

=item object

Name of the object being retrieved.

=item cols

Reference to a list of field names.

=item RETURN

Returns a reference to a list of field names to retrieve.

=back

=cut

sub _select_list {
    my ($p3, $object, $cols) = @_;
    # The field names will be accumulated in here.
    my %retVal;
    # Get the modified-field hashes.
    my $derivedH = DERIVED->{$object};
    my $relatedH = RELATED->{$object};
    # Loop through the field names.
    for my $col (@$cols) {
        my $algorithm = $relatedH->{$col};
        if ($algorithm) {
            $retVal{$algorithm->[0]} = 1;
        } else {
            $algorithm = $derivedH->{$col} // ['altName', $col];
            my ($function, @parms) = @$algorithm;
            for my $parm (@parms) {
                $retVal{$parm} = 1;
            }
        }
    }
    # Insure we have the ID column.
    $retVal{IDCOL->{$object}} = 1;
    # Return the fields needed.
    return [sort keys %retVal];
}

1;
