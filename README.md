
RIT DPRL CROHME 2013
---------------
DPRL CROHME 2013

Copyright (c) 2013-2014 Lei Hu, Kenny Davila, Francisco Alvaro, Richard Zanibbi


DPRL CROHME 2013 is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

DPRL CROHME 2013 is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with DPRL Hidden Markov Model (HMM) Math Symbol Classifier.  If not, see <http://www.gnu.org/licenses/>.

Contact:
- Lei Hu: lei.hu@rit.edu
- Kenny Davila: kxd7282@rit.edu
- Francisco Alvaro: falvaro@dsic.upv.es
- Richard Zanibbi: rlaz@cs.rit.edu 

This document is about DPRL's submission for the [CROHME 2013]. CROHME is the abbreviation of Competition on Recognition of Online Handwritten Mathematical Expression

The handwritten mathematical expression is preprocessed and rendered to an image. Symbol segmentation considers strokes in time series, using a binary AdaBoost classifier to determine which stroke pairs to merge.  Then for each stroke, we compute three kinds of shape context features (stroke pair, local neighborhood and global shape contexts) with different scales, 21 stroke pair geometric features and symbol classification scores for the current stroke and stroke pair. The stroke pair shape context features covers the current stroke and the following stroke in time series. The local neighborhood shape context features includes the current stroke and its three nearest neighbor strokes in distance while the global shape context features covers the expression. Principal component analysis (PCA) is used for dimensionality reduction.
The details of the segmentation can be found in the paper [Segmenting Handwritten Math Symbols Using AdaBoost and Multi-Scale Shape Context Features].

Symbol classification is performed by a set of boosted C4.5 decision trees obtained using AdaBoost.M1. Input strokes are resampled using cubic splines, with features including number of strokes, aspect ratio, covariance matrix of sample points, fuzzy histograms of line orientations, and a set of line crossings/cross-counts in different orientations. This produces a single symbol set. More details about the symbol classifier can be found at [DPRL_Math_Symbol_Recs]. 

The parser recursively: 1) groups vertical structures (e.g. fractions, summations and square roots), 2) extracts the dominant operator (e.g. fraction line) in each vertical group, and then 3) locates symbols on the main baseline, and on the main baselines in superscripted and subscripted regions by finding an MST defined over candidate symbol pairs with their associated classes and spatial relationship, and then 4) repeats the procedure in nested regions of vertical structures (e.g. fraction numerators and denominators). 

Spatial relationships are classified as inline, superscript or subscript by a Support Vector Machine, using bounding box geometry and a shape context feature for the region around symbol pairs. The details of spatial relationship classifier can be found in the paper [A shape-based layout descriptor for classifying spatial relationships in handwritten math].
How to run the codes?
----
The codes for the spatial relationship classifier are writeen in C++. All the other parts are written in Python. The version of Python we need is Python 2.7.3 or above.

The usage is: python DPRL.pyc DPRL_CROHME2013 <input_path> <output_path>

Both input_path and output_path are abosolute path. The input_path contains the xxx.inkml files need to be recognized and the output_path contains the recognition results xxx.lg with inherited relationships.

The input inkml file is in the format of CROHME and the description of the data file format can be found at [CROHME data format].
The output .lg file is label graph file and its format can be found at [label graph file format].
A Label Graph is a labeled adjacency matrix representation for a graph.
More details about label graph and inherited relationships can be found in the paper [Evaluating structural pattern recognition for handwritten math via primitive label graphs].

Library CROHMELib is needed to produce the .lg file. The details of CROHMElib can be found in [CROHMELib document]. 


[CROHME 2013]:http://ieeexplore.ieee.org/xpl/articleDetails.jsp?tp=&arnumber=6628849&queryText%3DCROHME+2013

[Segmenting Handwritten Math Symbols Using AdaBoost and Multi-Scale Shape Context Features]:http://ieeexplore.ieee.org/xpl/articleDetails.jsp?tp=&arnumber=6628800&queryText%3D%5BSegmenting+Handwritten+Math+Symbols+Using+AdaBoost+and+Multi-Scale+Shape+Context+Features%5D

 [A shape-based layout descriptor for classifying spatial relationships in handwritten math]:http://dl.acm.org/citation.cfm?id=2494315
 
 [CROHME data format]:http://www.isical.ac.in/~crohme/data2.html
 
 [label graph file format]:http://www.cs.rit.edu/~dprl/CROHMELib_LgEval_Doc.html
 
 [Evaluating structural pattern recognition for handwritten math via primitive label graphs]:http://www.cs.rit.edu/~dprl/Publications.html
 
 [CROHMELib document]:http://www.cs.rit.edu/~dprl/CROHMELib_LgEval_Doc.html
 
 [DPRL_Math_Symbol_Recs]:http://www.cs.rit.edu/~dprl/Software.html

