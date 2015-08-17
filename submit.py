import argparse
import os
import shutil
import glob
import datetime

parser = argparse.ArgumentParser(description='Create Kerner input file and submit job.',
                                 formatter_class=argparse.RawTextHelpFormatter)

parser.add_argument('jobname', help='Job directory name')

helptext = """Input file to use. It will overwrite default values, 
but will be overwritten by any argument to this function."""
parser.add_argument('-i', '--input_file', help=helptext)

parser.add_argument('-n', '--nslaves', type=int, default=2,
                    metavar='N', 
                    help='Number of slaves to use')

parser.add_argument('-m', '--message', 
                    help="Description of run, which is saved in jobname/README.run\n"+
                         "If omitted, an editor window opens to collect description.")

parser.add_argument('--what_to_do', choices=['integrate_kernel', 'plot_wavefield'], 
                    default='integratekernel',
                    help='Calculate kernels or just plot wavefields')


###############################################################################
# AxiSEM wavefield directories
###############################################################################

axisem_dirs = parser.add_argument_group('AxiSEM run directories')
axisem_dirs.add_argument('--fwd_dir', default='./wavefield/fwd/',
                    help='Path to AxiSEM forward run')
axisem_dirs.add_argument('--bwd_dir', default='./wavefield/bwd/',
                    help='Path to AxiSEM backward run')

###############################################################################
# input files
###############################################################################

input_files = parser.add_argument_group('Required input files')
input_files.add_argument('--src_file', default='CMTSOLUTION',
                    help='Path to source solution file in CMTSOLUTION format')
input_files.add_argument('--rec_file', default='receiver.dat',
                    help='Path to receiver and kernel file')
input_files.add_argument('--filt_file', default='filters.dat',
                    help='Path to filter file')
input_files.add_argument('--stf_file', default='stf_20s.dat',
                    help='Path to Source Time Function file')

###############################################################################
# Mesh file-related options
###############################################################################

mesh_files = parser.add_argument_group('Inversion mesh')
mesh_helptext = """
Select the mesh file type. Allowed values are 
abaqus      : .inp file, can be generated with Qubit or other codes. Can
              contain various geometries and multiple sub-objects
              Supported geometries: tetrahedra, triangles, quadrilaterals
              Set file name in MESH_FILE_ABAQUS 

tetrahedral : tetrahedral mesh in two separate files with 
              1. coordinates of the vertices (MESH_FILE_VERTICES)
              2. the connectivity of the facets of the tetrahedrons
                 (MESH_FILE_FACETS)"""
mesh_files.add_argument('--mesh_file_type', default='abaqus',
                        choices=['abaqus', 'tetrahedral'], help=mesh_helptext)
mesh_files.add_argument('--mesh_file_abaqus', default='Meshes/flat_triangles.inp',
                    help='Path to Abaqus mesh file')
mesh_files.add_argument('--mesh_file_vertices', default='unit_tests/vertices.TEST',
                    help='Path to Vertices file (only if --mesh_file_type=tetrahedral)')
mesh_files.add_argument('--mesh_file_facets', default='unit_tests/facets.TEST', 
                    help='Path to Facets file (only if --mesh_file_type=tetrahedral)')

###############################################################################
# Kernel-related options
###############################################################################

kernel_options = parser.add_argument_group('Kernel calculation options')
helptext = """
Calculate kernels for absolute values Vp instead of relative perturbations dVp 
with respect to the background model""" 

kernel_options.add_argument('--kernel_for_absolute_perturbations', action="store_true", default=False,
                            help=helptext)

helptext = """On which base functions are the kernels defined?
volumetric (default): Each voxel is a base function (Boschi & Auer)
onvertices:           Each vertex has a set of non-orthogonal base functions
                      defined on it (Nolet & Sigloch)"""
kernel_options.add_argument('--int_type', choices=['volumetric', 'onvertices'], 
                            default='volumetric', help=helptext)
helptext = """
For plotting reasons one may wish to skip the integration over cell-volume.
Resulting kernels bear the unit [s/m^3]"""
kernel_options.add_argument('--no_int_over_volume', action="store_true", default=False,
                            help=helptext)


###############################################################################
# Monte Carlo-related options
###############################################################################

mc_options = parser.add_argument_group('Monte Carlo options')
helptext = """
Number of points on which the kernel is evaluated per 
Monte Carlo step. Default value is 4."""
mc_options.add_argument('--points_per_mc_step', type=int, default=4,
                        help=helptext)
helptext = """Maximum number of Monte Carlo iterations. Allows to skip 
evaluation of single problematic cells. Default value is 1E6"""
mc_options.add_argument('--maximum_iterations', type=int, default=1000000,
                        help=helptext)
helptext = """Allowed absolute error before Monte Carlo integration is considered
to be converged. When calculating this value, the volume is not considered,
no matter whether --no_int_over_volume is set or not."""
mc_options.add_argument('--allowed_error', type=float, default=1e-4,
                        help=helptext)
helptext = """Allowed relative error before Monte Carlo integration in one cell
is considered to be converged. Default value is 1e-2"""
mc_options.add_argument('--allowed_relative_error', type=float, default=1e-2,
                        help=helptext)
helptext = """Use pseudorandom numbers instead of quasirandom"""
mc_options.add_argument('--use_pseudorandom_numbers', action="store_true", default=False,
                        help=helptext)

###############################################################################
# Debugging-related options
###############################################################################

debug_options = parser.add_argument_group('Debugging options')
helptext = """
This activates the optional (linearity test) to integrate relative kernels over
model perturbations in percent, to assess how well our kernels predict measured
traveltime perturbations for the same model. This only makes sense when not 
calculating absolute kernels. """
debug_options.add_argument('--int_over_3d_heterogeneities', action="store_true", default=False,
                    help=helptext)
helptext = """Path to heterogeneity file"""
debug_options.add_argument('--het_file', default='unit_tests/savani.rtpv',
                    help=helptext)

helptext = """
Integrate the kernel over the background model. Classically, this was assumed
to result in the travel time of a phase. This assumption is highly dubious for
wavefield-derived kernels. For legacy reasons, we can still leave it in. 
Adds a version of the background model interpolated on the inversion mesh to 
the output file."""
debug_options.add_argument('--int_over_background_model', action="store_true", default=False,
                    help=helptext)

helptext = """ Every slave writes out the values of all the kernels and their respective 
estimated errors into his OUTPUT_??? file after each MC step. This can lead 
to huge ASCII files (>1GB) with inane line lengths (approx. 20 x nkernel).
However, it might be interesting to study the convergence behaviour. """
debug_options.add_argument('--write_detailed_convergence', action="store_true", default=False,
                           help=helptext)

helptext = """Do not deconvolve the Source Time Function and reconvolve with 
the one set in --stf_file, but just timeshift the wavefields."""
debug_options.add_argument('--no_deconvolve_stf', action="store_true", default=False,
                           help=helptext)

helptext = """Integration scheme to calculate scalar kernels from seismograms and waveforms. 
parseval (default):  Integration in frequency domain, using the Parseval theorem.
trapezoidal:         Integration in time domain using the trapezoidal rule."""
debug_options.add_argument('--integration_scheme', choices=['parseval', 'trapezoidal'], 
                           default='parseval', help=helptext)


###############################################################################
# Output-related options
###############################################################################

output_options = parser.add_argument_group('Output options')
helptext = """Output format when dumping kernels and wavefields. 
Choose between xdmf, Yale-style csr binary format (compressed sparse row) and
ascii. Yet, the allowed error below is assumed as the truncation threshold in 
csr and ascii storage"""
output_options.add_argument('--dump_type', choices=['xdmf', 'ascii', 'csr'], default='xdmf',
                    help=helptext)
helptext = """Write out Seismograms (raw full trace, filtered full trace 
and cut trace) into run_dir/SEISMOGRAMS. Produces three files per kernel. 
Disable to avoid congesting your file system."""
output_options.add_argument('--write_seismograms', default=False,
                            help=helptext)
helptext = """Prefix of output file names.
Kernel files are called $OUTPUT_FILE_kernel.xdmf
Wavefield movies are called $OUTPUT_FILE_wavefield.xdmf"""
output_options.add_argument('--out_prefix', default='kerner',
                            help=helptext)

###############################################################################
# Performance-related options
###############################################################################

performance_options = parser.add_argument_group('Performance-related options')
helptext = """Size of buffer for strain values. Since the strain has to be 
calculated from the displacement stored in the AxiSEM files,
increasing this buffer size saves IO access and CPU time."""
performance_options.add_argument('--strain_buffer_size', type=int, default=1000,
                            help=helptext)

helptext = """Size of buffer for displacement values. Displacement values are
use to calculate strain later. Having a separate buffer here allows to save 
some IO accesses."""
performance_options.add_argument('--displ_buffer_size', type=int, default=100,
                            help=helptext)
helptext = """Number of elements per Slave task. A larger value allows to the
Slave to have more contiguous parts of the earth to work on, smaller values
improve load balancing. It should be chosen such that each slave gets at least
50-100 tasks to work on."""
performance_options.add_argument('--elements_per_task', type=int, default=100,
                            help=helptext)
helptext = """Do not sort the mesh elements. Just for debugging."""
performance_options.add_argument('--no_sort_mesh_elements', action="store_true", default=False,
                            help=helptext)
helptext = """Mask the source and the receiver element and set the kernel to 
zero in each. A rough way to avoid spending hours until convergence in these 
two elements in reached."""
performance_options.add_argument('--mask_source_receiver', action="store_true", default=False,
                            help=helptext)
helptext = """Dampen the kernel in a radius around source and receiver. 
If a negative value is chosen, damping is switched off (default)."""
performance_options.add_argument('--damp_radius_source_receiver', type=float, default=-100.E3,
                                 help=helptext)
helptext = """FFTW Planning to use 
Options: 
ESTIMATE:   Use heuristic to find best FFT plan
MEASURE:    Compute several test FFTs to find best plan (default)
PATIENT:    Compute a lot of test FFTs to find best plan
EXHAUSTIVE: Compute an awful amount of test FFTs to find best plan
This option did not prove to be very useful on most systems."""
performance_options.add_argument('--fftw_plan', default='MEASURE',
                    choices=['ESTIMATE', 'MEASURE', 'PATIENT', 'EXHAUSTIVE'],
                    help=helptext)

args = parser.parse_args()

# Parse input file, if one was given
if args.input_file: 
  with open(args.input_file) as f:
    args_input_file = {}
    for line in f:
      # Skip comment and empty lines
      if line[0]!='#' and line.strip()!='':
        (key, val) = line.split()
        args_input_file[key] = val

# Sanitize input variables
params = {}
# Loop over all possible arguments
for key, value in vars(args).iteritems():
  if not key in ('nslaves', 'jobname'): 
    # If an input file is selected, get values from there by default
    if args.input_file:
      if value == parser.get_default(key):
        key_out   = key.upper()
        value_out = str(args_input_file[key.upper()])
      else:
        # Unless values were explicitly given
        key_out = key.upper()
        value_out = str(value)
    else:
      # In all other cases, take default values
      key_out = key.upper()
      value_out = str(value)

  params[key_out] = value_out

params_out = {}

# Create run_dir
run_dir = args.jobname
os.mkdir(run_dir)

# Copy necessary files to rundir
for key, value in params.iteritems():

  if key in ('NSLAVES', 'JOBNAME', 'MESH_FILE_ABAQUS', 'MESH_FILE_VERTICES', 'MESH_FILE_FACETS', 
             'HET_FILE', 'INPUT_FILE', 'MESSAGE'): 
    # Effectively nothing to do
    print ''
  elif key=='SRC_FILE':
    shutil.copy(value, os.path.join(run_dir, 'CMTSOLUTION'))
    params_out[key] = 'CMTSOLUTION'
  elif key=='REC_FILE':
    shutil.copy(value, os.path.join(run_dir, 'receiver.dat'))
    params_out[key] = 'receiver.dat'
  elif key=='FILT_FILE':
    shutil.copy(value, os.path.join(run_dir, 'filters.dat'))
    params_out[key] = 'filters.dat'
  elif key=='STF_FILE':
    shutil.copy(value, os.path.join(run_dir, 'stf.dat'))
    params_out[key] = 'stf.dat'

  elif key=='MESH_FILE_TYPE':
    params_out[key] = value
    if args.mesh_file_type=='abaqus':
      shutil.copy(params['MESH_FILE_ABAQUS'], os.path.join(run_dir, 'mesh.inp'))
      params_out['MESH_FILE_ABAQUS'] = 'mesh.inp'
    else:
      shutil.copy(params['MESH_FILE_VERTICES'], os.path.join(run_dir, 'mesh.VERTICES'))
      shutil.copy(params['MESH_FILE_FACETS'], os.path.join(run_dir, 'mesh.FACETS'))
      params_out['MESH_FILE_VERTICES'] = 'mesh.VERTICES'
      params_out['MESH_FILE_FACETS'] = 'mesh.FACETS'

  elif key=='INT_OVER_3D_HETEROGENEITIES':
    params_out[key] = value
    shutil.copy(args.het_file, os.path.join(run_dir, 'heterogeneities.dat'))
    params_out['HET_FILE'] = 'heterogeneities.dat'
  elif key in ('FWD_DIR', 'BWD_DIR'):
    # Set mesh dir to absolute path
    params_out[key] = os.path.realpath(value)

  else:
    params_out[key] = value

# Open editor window to write run descriptor
out_readme = 'readme_temp.txt' 
f_readme = open(out_readme, 'w')
f_readme.write('MC KERNEL run for %d CPUs, started on %s\n'%(args.nslaves, 
                                                           str(datetime.datetime.now())))
f_readme.write('  by user ''%s'' on ''%s''\n'%(os.environ.get('USER'), 
                                               os.environ.get('HOSTNAME')))
if args.message:
  f_readme.write(args.message)
  f_readme.close()
else:
  f_readme.close()
  editor = os.environ.get('EDITOR')
  os.system('%s %s'%(editor, out_readme))

# Move README file to rundir
shutil.move(out_readme, os.path.join(run_dir, 'README.run'))

# Create directory for seismogram output
os.mkdir(os.path.join(run_dir, 'Seismograms'))

# Create input file for run
out_input_file = os.path.join(run_dir, 'inparam')
with open(out_input_file, 'w') as f_out:
  for key, value in params_out.iteritems():
    if value.find('/')==-1:
      f_out.write('%s  %s\n'%(key, value))
    else:
      f_out.write('%s "%s"\n'%(key, value))

# Get mpirun from make_kerner.macros
with open('make_kerner.macros') as f:
  for line in f:
    if line.strip()!='':
      key = line.split()[0]
      if key=='MPIRUN':
        mpirun_cmd = line.split()[2]

# Make kerner code 
os.system('make -sj')

# Copy code files into run_dir, tar it and delete it.
# A bit clumsy, but ensures that the internal path is Code/*.f90 etc.
code_dir = os.path.join(run_dir, 'Code')
archive_name = os.path.join(run_dir, 'Code')
os.mkdir(code_dir)
for f90_file in glob.glob('*.f90'):
  shutil.copy(f90_file, code_dir)
shutil.copy('Makefile', code_dir)
shutil.copy('make_kerner.macros', code_dir)
shutil.make_archive(archive_name, 'gztar', code_dir)
shutil.rmtree(code_dir)


# Change dir and submit
os.chdir(run_dir)

os.system('%s -n %d ../kerner inparam'%(mpirun_cmd, args.nslaves))
