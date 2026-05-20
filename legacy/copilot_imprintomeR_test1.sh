##################################################################
# started: 04/07/2026,11:42:53 
##################################################################

imprintomeR/
├── .github/
│   └── copilot-instructions.md   ✅ auto-used by Copilot
│
├── docs/
│   ├── methods-contract.md       ✅ scientific rules
│   ├── package-roadmap.md
│   ├── plot-specs.md
│   └── function-index.md
│
├── skills/
│   ├── r-package-maintainer.md
│   ├── stat-method-guardrails.md
│   ├── ggplot-bioinformatics-figures.md
│   └── testthat-method-validation.md
│
├── prompts/
│   ├── package-refactor.prompt.md
│   ├── roxygen-tests.prompt.md
│   └── plotting-review.prompt.md
│
├── R/
├── tests/
├── vignettes/
└── DESCRIPTION

mkdir .github docs skills prompts

touch prompts/package-refactor.prompt.md
touch .github/copilot-instructions.md
touch prompts/plotting-review.prompt.md
touch docs/methods-contract.md
touch docs/plot-specs.md
touch docs/package-roadmap.md
touch docs/function-index.md
touch skills/r-package-maintainer.md
touch skills/stat-method-guardrails.md
touch skills/ggplot-bioinformatics-figures.md
touch skills/testthat-method-validation.md  

# ask Copilot to draft the content for the following files:
provide concise, single-section of package-roadmap.md
provide concise, single-section of function-index.md
provide concise, single-section of r-package-maintainer.md
provide a concise, single-section of stat-method-guardrails.md
provide a concise, single-section of ggplot-bioinformatics-figures.md
provide a concise, single-section of testthat-method-validation.md
#================================================================
🚀 Step 1 — Make sure Copilot sees your instructions

Open your repo and confirm:

.github/copilot-instructions.md   ✅ (auto-used)
docs/methods-contract.md         ✅ (you will reference)
skills/*.md                      ✅ (you will reference)
prompts/*.md                     ✅ (you will reuse)

👉 Open .github/copilot-instructions.md once in the editor
(This helps Copilot load it into context)

#================================================================
🚀 Step 2 — Start Copilot Chat (NOT inline suggestions)

Use:

VS Code → Copilot Chat panel

or shortcut: Ctrl + Alt + I (or similar)

👉 Always use Chat mode for this project
Inline suggestions are too weak for this level of work.

#================================================================
Task 1 — Identify modules
Analyze utilities2.R and group functions into modules:
- IO
- probeset handling
- scoring
- aggregation
- plotting
- utilities

List which functions go into each module.
Do not modify code yet.
#================================================================
@workspace Refactor utilities2.R into package modules.
Follow docs/methods-contract.md.

@workspace
You are working inside the imprintomeR package.

Refactor Refactor AnalyzeImprintStatus() into modular functions in module_scoring.R file

Follow:
- docs/methods-contract.md
- skills/stat-method-guardrails.md

Create:
- compute_ids()
- compute_angle()
- classify_mechanism()

Do not change formulas. Don't break original functions until the new ones are ready and tested.
Add roxygen2 documentation.

Confirm plan before implementation.



#================================================================
Task 3 — Refactor plotting
@workspace Refactor plotting in module_plotting.R file

Follow:
- skills/ggplot-bioinformatics-figures.md
- docs/plot-specs.md

Standardize:
- return ggplot object
- optional file saving
- consistent colors and labels

Add roxygen2 documentation.
Don't break original functions until the new ones are ready and tested.

Confirm plan before implementation.

#================================================================

@workspace update run_impritomeR2.R and save as run_impritomeR1.R to test major functions of this package. Use the new modular functions from module_scoring.R and module_plotting.R etc, independent of utilities2.R.

@workspace  work on module_probeset.R: 1 compare ExtractProbesByBeds2 and ExtractProbesByBeds, keep one or harmonize them into one function ; 2 delete funtions Create.anno.EPICv2,ICR_Filepath,AnnotateProbesetCytoband ; 3 move functions  Beeplot_chr_vs_other and Beeplot_chr_vs_other_single to module_plotting.R; 
Add roxygen2 documentation.
Dont break original functions until the new ones are ready and tested.

Confirm plan before implementation.
#================================================================

@workspace Add roxygen2 documentation to module_io.R

@workspace Add roxygen2 documentation to module_aggregation.R

#================================================================
@workspace   create reusuable function compute_consistency() from AnalyzeImprintStatus() and Refactor AnalyzeImprintStatus() in module_scoring.R accordingly ;   
#================================================================




@workspace

I want to introduce a formal container object for this package called ImprintomeSet so functions stop passing beta, meta, and probesets independently.

Follow:
- .github/copilot-instructions.md
- docs/methods-contract.md
- skills/r-package-maintainer.md
- skills/stat-method-guardrails.md

Task:
Design an S4 class called ImprintomeSet for imprintomeR.

Required slots:
- beta
- meta
- probeset
- genome
- assay
- results
- plots

Required methods:
- runImprintome()
- plot()
- summarize()
- export()

Requirements:
- Do not change scientific behavior
- Keep AnalyzeImprintStatus(), LoadMetaBeta(), MirrorDensity(), and Calculate_impvar() behavior compatible
- Propose how these existing functions should work with the new object
- Recommend whether S4 or R6 is a better fit for this package and explain why
- Start by producing:
  1. class design
  2. file layout
  3. method signatures
Do not generate all code yet.

#----------------------------------------------------------------
# Prompt 2: choose S4 vs R6
Based on this package, choose  S4

I want:
- Bioconductor-style compatibility
- formal validation
- stable slots
- easy interoperability with existing matrix/data.frame workflows

Give a concise recommendation, then draft the class definition only.

#----------------------------------------------------------------
#Prompt 3: create the class file
Create R/ImprintomeSet-class.R

Implement an S4 class ImprintomeSet with slots:
- beta = matrix or data.frame
- meta = data.frame
- probeset = data.frame or list
- genome = character
- assay = character
- results = list
- plots = list

Add:
- setClass()
- constructor ImprintomeSet()
- validity checks

Requirements:
- validate beta/meta sample consistency
- validate row/column structure where possible
- keep code readable
- add roxygen2 docs
Do not implement methods yet.

#----------------------------------------------------------------
# Prompt 4: add accessors
Create accessors and replacement methods for ImprintomeSet.

Add:
- beta()
- meta()
- probeset()
- genome()
- assay()
- results()
- plots()

Include setters where appropriate.

Keep  them simple and Bioconductor-like.
Add roxygen2 docs.

#----------------------------------------------------------------
#Prompt 5: wrap existing functions
Use module_*.R as the source of truth.
check my docs/function-index.md and identify which functions to support ImprintomeSet input:.

Requirements:
- preserve current behavior for old inputs
- also allow x to be an ImprintomeSet object
- if x is ImprintomeSet, pull needed slots from the object
- do not change formulas
- add method signatures or wrapper functions as appropriate
Show the refactor plan before generating code.

#----------------------------------------------------------------
#Prompt 6: create runImprintome
Create a user-facing function runImprintome() for ImprintomeSet.

Behavior:
- take an ImprintomeSet object
- run core analysis using the packages existing logic
- store outputs into @results
- return updated ImprintomeSet

Use AnalyzeImprintStatus() as the starting scientific logic.
Do not change IDS, Angle, IDI, or aggregation rules.
Add roxygen2 docs and a simple example.
#----------------------------------------------------------------
# Prompt 7: add summarize and export
Create summarize() and export() methods for ImprintomeSet.

summarize():
- return a concise summary of slots and results
- report dimensions, assay, genome, probeset info

export():
- write selected results tables to disk
- optionally save plots already stored in @plots

Keep behavior deterministic and simple.
Add roxygen2 docs.
#----------------------------------------------------------------
# Prompt 8: add plot method
Create an S4 plot method for ImprintomeSet.

Behavior:
- dispatch to stored plots if available
- or generate a default plot from results
- default to PlotPolar() if IDS/Angle results are present

Requirements:
- keep plot semantics consistent with plot-specs.md
- return ggplot object
- optionally save to file
Do not change scientific meaning.
#----------------------------------------------------------------
# Prompt 9: add tests

Write testthat tests for ImprintomeSet.

Test:
- constructor works
- invalid beta/meta mismatch fails
- slots are stored correctly
- runImprintome() updates results
- old functions still work with non-object inputs
- AnalyzeImprintStatus() works with ImprintomeSet input

Use small synthetic data.


#================================================================
cd projects/imprintomeR1/
Rscript -e "testthat::test_file('tests/testthat/test-imprintomeset.R')"

#================================================================

@workspace

Goal:
Refactor this package so that ImprintomeSet becomes the primary data container, instead of passing beta, meta, and probesets separately.

Follow:
- .github/copilot-instructions.md
- docs/methods-contract.md
- skills/r-package-maintainer.md
- skills/stat-method-guardrails.md

Requirements:
- Do NOT change scientific behavior (IDS, Angle, IDI, aggregation)
- Maintain backward compatibility with current function signatures
- Prefer adding support for ImprintomeSet rather than removing existing arguments
- Refactor incrementally, not all at once

Task:
1. Identify all functions that currently take beta, meta, or probeset
2. Propose a refactoring plan to support ImprintomeSet
3. Show:
   - which functions should be updated
   - which should become internal helpers
   - which should become methods
   - how data flows through the object


#================================================================
 generate vignettes for imprintomeSet based workflow


 Rscript -e "rmarkdown::render('vignettes/imprintomeset-quickstart.Rmd', quiet=TRUE); rmarkdown::render('vignettes/imprintomeset-results-export.Rmd', quiet=TRUE); rmarkdown::render('vignettes/imprintomeR-workflow.Rmd', quiet=TRUE)"

 #pandoc vignettes/imprintomeset-quickstart.Rmd > ../imprintomeset-quickstart.html
 #pandoc vignettes/imprintomeset-results-export.Rmd > ../imprintomeset-results-export.html

buildRpackage.sh -d /home/hjin/projects/ -p imprintomeR1 -m 1
buildRpackage.sh -d /home/hjin/projects/ -p imprintomeR1 -m 3
R CMD INSTALL --library=/home/hjin/R/x86_64-pc-linux-gnu-library/4.1.0 imprintomeR_0.1.0.tar.gz


#================================================================

 @workspace generate bioconduct style vignettes for imprintomeSet based workflow. Use the new runImprintome() function as the main workflow example. Show how to create an ImprintomeSet object, run the analysis, summarize results  and demonstrate all visualizations.

 @workspace add @export tags to all public functions in the package, and ensure that internal helper functions are not exported. Follow Bioconductor guidelines for documentation and export.

 @workspace  use codes module_plotting.R to implement imprintomeSet based plotting functions into  ImprintomeSet-plot.R  Do not generate all code yet. Let me review the plan first.


R -q -e "roxygen2::roxygenise('.', roclets = c('namespace','rd'))"
R -q -e "testthat::test_file('tests/testthat/test-imprintomeset-plotting.R')"

@workspace in vignettes, include all available plot_types to demo all visualizations
Rscript -e "roxygen2::roxygenise('.', roclets = c('namespace','rd'))"
 Rscript -e "rmarkdown::render('vignettes/imprintomeset-quickstart.Rmd', quiet=TRUE); rmarkdown::render('vignettes/imprintomeset-results-export.Rmd', quiet=TRUE); rmarkdown::render('vignettes/imprintomeR-workflow.Rmd', quiet=TRUE)"

@workspace specifically imprintomeset-quickstart.md, provide example code for each plot type, and show how to access the plots from the ImprintomeSet object. Use a small synthetic dataset for the examples if possible.

 @workspace  update imprintomeset-quickstart.Rmd, imprintomeset-results-export.Rmd, and imprintomeR-workflow.Rmd as follows
rainfall and radar plots require a sample_id argument. use the example code to show how to specify sample_id when calling plot() for these plot types . 
sample_id1 <- colnames(beta(x))[2]
outFile = paste0( "imprintomeset_quickstart_rainfall_", sample_id1, ".pdf")
p_rainfall <- plot(
  x,
  plot_type = "rainfall",
  sample_id = sample_id1,
  probeset = "classifier3",
  outFile = outFile
)
outFile = paste0("imprintomeset_quickstart_radar_", sample_id1, ".pdf")
p_radar <- plot(
  x,
  plot_type = "radar",
  probeset = "selected",
  sample_id = sample_id1,
  title = "ImprintomeSet Radar",
  outFile = outFile
)

 @workspace   1) show sample_id1 as subtitle in the radar plot and rainfall plot. 2) use IDI and set y-axis limits to -1 to + 1 for the rainfall plot. 3) use consistent color scheme for both plots. 4) add informative axis labels and legends to both plots. 5) ensure that the sample_id is clearly indicated in the plot titles or subtitles for both plots.  Review  the plan before implementation.

  @workspace  review BetaBeePlot_orgin() and  BetaBeePlot_orgin2() in module_plotting.R to implement two additional functions for ImprintomeSet 1) beeswarm_origin() for a cohort of samples and 2) beeswarm_chr() for single sample but facet by chromosome information in probeset.  readRDS("inst/extdata/probesets_hg19.rds") contains the probeset information for the beeswarm plot. both new functions should  live in ImprintomeSet-plot.R only.
   3) use a consistent color scheme for the beeswarm plot that matches the other plots in the package. 4) add informative axis labels and legends to the beeswarm plot to enhance interpretability. 5) ensure that the chromosome of interest is clearly indicated in the plot title or subtitle for the beeswarm plot. Review the plan before implementation. 6) add example of how to call these two new functions in the vignette, and show how to access the plot from the ImprintomeSet object.  show me the plan before implementation.

 Rscript -e "roxygen2::roxygenise('.', roclets = c('namespace','rd'))"
 Rscript -e "rmarkdown::render('vignettes/imprintomeset-quickstart.Rmd', quiet=TRUE); rmarkdown::render('vignettes/imprintomeset-results-export.Rmd', quiet=TRUE); rmarkdown::render('vignettes/imprintomeR-workflow.Rmd', quiet=TRUE)"

@workspace  improve the facet logic in two new fucntions beeswarm_origin() and beeswarm_chr() . beeswarm_origin() should use sample ID as x-axis and parental origin as fill color, dots of same sample should be display side by side. beeswarm_chr() should use chromosome information as x-axis and parental origin as fill color.  show me the plan before implementation. 

@workspace  use code block below of BetaBeePlot_orgin() in module_plotting.R as the source of truth  to implement beeswarm_origin() in ImprintomeSet-plot.R.  review the plan before implementation.
    pg_sep <- ggplot(used, aes(x = interaction(ID, CATEGORY), y = value, color = CATEGORY)) +
        geom_quasirandom(size = dotSize, alpha = alpha, pch=20) + 
        stat_summary(fun = median, geom = "errorbar", aes(ymin = after_stat(y), ymax = after_stat(y)), 
                    width = 0.75, linewidth = 0.8, color="grey30") + 
        facet_wrap(~ ID, nrow = 1, scales = "free_x", strip.position = "bottom") + 
        scale_x_discrete( labels = function(x) {
          labels <- rep("", length(x))
          labels[seq(1, length(x), by = num_groups)] <- unlist(strsplit(as.character(x), "\\."))[1]
          labels
      }) +
        theme_minimal() + 
        theme_classic(base_size = 10) +
        labs(y = "Methylation Level", x = "ID") +
        theme(axis.text.x = element_text(angle = 90, hjust = 1), 
              axis.title.x = element_blank(),
              axis.ticks.x = element_blank(),
              strip.text = element_blank(), 
              strip.background = element_blank())


@workspace  use BetaBeeswarm_chr_color() in  module_plotting.R as the source of truth to implement beeswarm_chr() in ImprintomeSet-plot.R; 

@workspace  update imprintomeset-quickstart.Rmd, imprintomeset-results-export.Rmd, and imprintomeR-workflow.Rmd accordingly to show how to use the new beeswarm plot functions, and how to access the plots from the ImprintomeSet object.  show me the plan before implementation.

git diff -- vignettes/imprintomeset-quickstart.Rmd vignettes/imprintomeset-results-export.Rmd vignettes/imprintomeR-workflow.Rmd

cd ..
buildRpackage.sh -d /home/hjin/projects/ -p imprintomeR1 -m 3
R CMD INSTALL --library=/home/hjin/R/x86_64-pc-linux-gnu-library/4.1.0 imprintomeR_0.1.0.tar.gz
 R CMD INSTALL . --library=/home/hjin/R/x86_64-pc-linux-gnu-library/4.1.0


BetaBeePlot_orgin

Rscript -e "roxygen2::roxygenise('.', roclets = c('namespace','rd'))"
 Rscript -e "rmarkdown::render('vignettes/imprintomeset-quickstart.Rmd', quiet=TRUE); rmarkdown::render('vignettes/imprintomeset-results-export.Rmd', quiet=TRUE); rmarkdown::render('vignettes/imprintomeR-workflow.Rmd', quiet=TRUE)"

 Rscript -e "rmarkdown::render('README.md', quiet=TRUE);" 

 # 
Created README_render.Rmd. It uses child='README.md' so it stays in sync automatically — any edit to README.md is reflected when you re-render.
 Rscript -e "rmarkdown::render('README_render.Rmd', quiet=TRUE);" 

######################################

Recommended flow
1 Run QC first.
2 Check array platform.
3 If samples come from more than one platform, such as 450K and EPICv1, split by platform and run QC separately for each subset.
4 Generate QC outputs for each platform subset:
   - QC metrics table
   - QC plots
   - beta value output
5 Create one ImprintomeSet per QC-clean, single-platform dataset.
6 Run runImprintome().
7 Generate imprintome analysis visualizations.
That is a better scientific boundary than putting QC inside the object lifecycle. ImprintomeSet should represent an analysis-ready cohort, not the raw mixed-platform intake.


# Run comprehensive test (8 steps, ~2 min)
export R_LIBS=/home/hjin/R/x86_64-pc-linux-gnu-library/4.1.0:$R_LIBS

Rscript test_methqcset_hpc.R

update imprintomeset-quickstart.Rmd, imprintomeset-results-export.Rmd, and imprintomeR-workflow.Rmd and README.md accordingly

implement something like plot(qcset, type = "qc_bar",outFile = "qc_bar_polar.pdf" ) to qc plots, and return ggplot2 object


#================================================================
 cut -f 1,3,5 RMS3D2D_meta_n9.txt > RMS3D2D_meta_n9_simple.txt

grep RMS3D2D_meta_n9.txt
grep -v EPICv2 RMS3D2D_meta_n9.txt |  cut -f 1,3,5  > RMS3D2D_meta_n4_EPICv1.txt

head -n 1  RMS3D2D_meta_n4_EPICv1.txt> RMS3D2D_meta_n5_EPICv2.txt
grep 'EPICv2' RMS3D2D_meta_n9.txt |  cut -f 1,3,5  >> RMS3D2D_meta_n5_EPICv2.txt


#================================================================

I have three meta files: RMS3D2D_meta_n4_EPICv1.txt, RMS3D2D_meta_n5_EPICv2.txt and RMS3D2D_meta_n9_simple.txt (mixed); generate a test.sh for me to run MethQcSet functions in these three senarios

Created two files:

test_methqcset_rms.sh — shell wrapper (checks meta files exist, sets R_LIBS, tees output to a timestamped log)

test_methqcset_rms.R — the actual test logic:

Scenario	Meta file	How platform is handled
1 EPICv1 only	RMS3D2D_meta_n4_EPICv1.txt	platform = "EPIC" passed explicitly
2 EPICv2 only	RMS3D2D_meta_n5_EPICv2.txt	platform = "EPICv2" passed explicitly
3 Mixed	RMS3D2D_meta_n9_simple.txt	check_platform() → split → runMethQC() per subset

cp test_methqcset_* test_set
cd test_set
cp ../test_methqcset_* .

bash test_methqcset_rms.sh

#================================================================

cd /home/hjin/projects/imprintomeR1
export R_LIBS=/home/hjin/R/x86_64-pc-linux-gnu-library/4.1.0:$R_LIBS
cd /home/hjin/projects/imprintomeR1
R CMD INSTALL . --library=/home/hjin/R/x86_64-pc-linux-gnu-library/4.1.0
Rscript -e "roxygen2::roxygenise('.', roclets = c('namespace','rd'))"
Rscript -e "rmarkdown::render('vignettes/imprintomeset-quickstart.Rmd', quiet=TRUE); rmarkdown::render('vignettes/imprintomeset-results-export.Rmd', quiet=TRUE); rmarkdown::render('vignettes/imprintomeR-workflow.Rmd', quiet=TRUE);" 

 Rscript -e "rmarkdown::render('README.md', quiet=TRUE);rmarkdown::render('README_render.Rmd', quiet=TRUE);" 

#================================================================
cd /home/hjin/projects/imprintomeR1/test_set/results_epicv1/analysis/plots
#T=file_pdf2jpg
ls *pdf >pdf.lst
pdf2jpg.sh -i pdf.lst -o ./

cd /home/hjin/projects/imprintomeR1/test_set/results_epicv1/plots
ls *pdf >pdf.lst
rm *jpg
pdf2jpg.sh -i pdf.lst -o ./
cd /home/hjin/projects/imprintomeR1

aveDetectionPval	<0.03
#================================================================

C:\Users\hjin\AppData\Local\Programs\R\R-4.3.3\bin\Rscript.exe

devtools::install('x:/projects/imprintomeR1')  

& "C:\Users\hjin\AppData\Local\Programs\R\R-4.3.3\bin\Rscript.exe" -e "devtools::test('x:/projects/imprintomeR1')" 2>&1 | tail -50
#================================================================
please re-install devtools::install('x:/projects/imprintomeR1') for me and then test Rscript test_circular_heatmap.R


cd /home/hjin/projects/imprintomeR1/test_set/results_epicv1/analysis/plots
#T=file_pdf2jpg
ls *pdf >pdf.lst
pdf2jpg.sh -i pdf.lst -o ./