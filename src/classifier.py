##    DPRL CROHME 2013
##    Copyright (c) 2013-2014 Lei Hu, Kenny Davila, Francisco Alvaro, Richard Zanibbi
##
##    This file is part of DPRL CROHME 2013.
##
##    DPRL CROHME 2013 is free software: 
##    you can redistribute it and/or modify it under the terms of the GNU 
##    General Public License as published by the Free Software Foundation, 
##    either version 3 of the License, or (at your option) any later version.
##
##    DPRL CROHME 2013 is distributed in the hope that it will be useful,
##    but WITHOUT ANY WARRANTY; without even the implied warranty of
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##    GNU General Public License for more details.
##
##    You should have received a copy of the GNU General Public License
##    along with DPRL CROHME 2013.  
##    If not, see <http://www.gnu.org/licenses/>.
##
##    Contact:
##        - Lei Hu: lei.hu@rit.edu
##        - Kenny Davila: kxd7282@rit.edu
##        - Francisco Alvaro: falvaro@dsic.upv.es
##        - Richard Zanibbi: rlaz@cs.rit.edu 

import pickle
import sys
import os
import fnmatch
import numpy as np
from c45_tree_node import *
from traceInfo import *
from mathSymbol import *


#==================================================
# Symbol Classifier using PCA or without PCA
#==================================================
class Classifier:
    def __init__(self, tree_file, pca_file):        
        #first, load the training results
        try:
            file = open(tree_file, 'r')    
            best_classifier = pickle.load(file)
            file.close()
            
            self.trees, self.alphas = best_classifier
        except:
            raise Exception(" Invalid Tree File ")

        #now, load the pca params
        if pca_file != None:
            try:
                pca_params = self.loadPCAParameters( pca_file )
                self.all_classes, self.normalization, self.pca_vectors, self.pca_k = pca_params
                self.pca_mode = True
            except:
                raise Exception( "Error loading PCA parameters" )
        else:
            self.pca_mode = False
            self.all_classes = self.deduceClasses()

    def deduceClasses(self):
        classes = { }
        for tree in self.trees:
            self.checkForClasses( tree, classes)

        return classes.keys()
            

    def checkForClasses(self, tree, class_dict):
        if tree.isLeaf():
            #base case...
            if not tree.own_class in class_dict:
                #add to dictionary...
                class_dict[tree.own_class] = True
        else:
            #go recursive...
            for child in tree.children:
                self.checkForClasses( tree.children[child], class_dict)
                

    #============================================
    # To work with PCA....
    #============================================
    def loadPCAParameters( self, file_name ):
        file_params = open(file_name, 'r')
        all_classes = pickle.load(file_params)
        normalization  = pickle.load(file_params)
        pca_vector  = pickle.load(file_params)
        pca_k  = pickle.load(file_params)    
        file_params.close()

        return (all_classes, normalization, pca_vector, pca_k)

    def getClassList(self):
        return self.all_classes

    def classify( self, trace_group ):
        #create the symbol object...
        symbol = self.createSymbol( trace_group )

        #get raw features
        features = symbol.getFeatures()
        
        if self.pca_mode:
            #get the features in PCA space
            features = self.featuresToPCA(features )            

        #do the actual classification...
        classes = self.probabilisticClassify( features )

        #now generate the sorted list...
        confidences = [ ]
        for label in self.all_classes:
            if label in classes:
                confidences.append( classes[label] )
            else:
                confidences.append( 0.0 )

        return confidences

    def mostProbableLabel( self, confidences ):
        most_probable = 0
        for i in range(1, len(confidences) ):
            if confidences[i] > confidences[most_probable]:
                most_probable = i

        return self.all_classes[most_probable], confidences[most_probable]

    def topNLabels( self, confidences, n_top ):
        top_relevant_indices = [ None for n in range(n_top) ]
        top_relevant_score = [ None for n in range(n_top) ]

        for i in range(len(confidences)):
            for k in range( n_top ):
                if top_relevant_indices[k] == None or top_relevant_score[k] < confidences[i]:
                    #empty bin or better score...
                    #insert ...
                    top_relevant_indices.insert( k, i )
                    top_relevant_score.insert( k, confidences[i] )
                    
                    #delete last position in the list...
                    del top_relevant_indices[-1]
                    del top_relevant_score[-1]
                        
                    #stop comparing
                    break

        results = []
        for k in range(n_top):
            i = top_relevant_indices[k]
            results.append( (self.all_classes[i], confidences[i] ) )

        return results

    def probabilisticClassify(self, values):    
        output_class = {}
        
        total_alpha = 0.0
        for i in range(len(self.trees)):
            labels = self.trees[i].probabilistic_evaluate(values)
            
            #normalize the weights...
            total_weight = 0.0
            for label in labels:
                total_weight += labels[label]
                                
            for label in labels:
                labels[label] /= total_weight
                            
                #add the alpha value multiplied by the current probability
                if label in output_class:
                    output_class[label] += self.alphas[i] * labels[label]
                else:
                    output_class[label] = self.alphas[i] * labels[label]
            
            total_alpha += self.alphas[i]    
        
        #now normalize...
        for label in output_class:
            output_class[label] /= total_alpha

        return output_class

    def createSymbol( self, trace_group ):
        #first, create the traceInfo...
        traces = []
        for trace_id, points_f in trace_group:
            #create object...
            object_trace = TraceInfo(trace_id, points_f )

            #apply general trace pre processing...        
            #1) first step of pre processing: Remove duplicated points        
            object_trace.removeDuplicatedPoints()

            #Add points to the trace...
            object_trace.addMissingPoints()

            #Apply smoothing to the trace...
            object_trace.applySmoothing()

            #it should not ... but .....
            if object_trace.hasDuplicatedPoints():
                #...remove them! ....
                object_trace.removeDuplicatedPoints()
                        
            traces.append( object_trace )

        #now create the symbol
        new_symbol = MathSymbol(traces, '{Unknown}')

        #normalization ...
        new_symbol.normalize()

        return new_symbol        

    def featuresToPCA(self, vector ):
        #first, apply normalization...

        #normalization
        values = []
        for att in range(len(vector)):
            att_mean, att_std = self.normalization[att]

            if att_std > 0.0:
                values.append( (vector[att] - att_mean) / att_std )
            else:
                values.append( (vector[att] - att_mean) )

        #now projection....
        #in case that K > # of atts, then just clamp....
        k = min(self.pca_k, len(vector))

        x = np.mat( values )
        projected = []
        for i in range(k):
            #use dot product to project...        
            p = np.dot(x, self.pca_vectors[i])[0, 0]

            projected.append( p.real )

        return projected

##def main():
##    #usage check
##    if len(sys.argv) < 2 or len(sys.argv) > 3:
##        print("Usage: python classifier.py tree_file [pca_params]")
##        print("Where")
##        print("\ttree_file\t= Path to the file with training results")
##        print("\tpca_params\t= (Optional) Path to the file with PCA parameters")
##        return
##
##    #DO NOT ATTACH CLASS LIST TO CLASSIFIER,
##    #GENERATE IT AND STORE IT WITH PCA PARAMETERS!!!!
##
##    try:
##        if len(sys.argv) == 3:
##            classifier = Classifier(sys.argv[1], sys.argv[2])
##        else:
##            classifier = Classifier(sys.argv[1], None)
##    except Exception as e:
##        print( e )
##        return
##
##    #simulated expression:
##    #   X = 1
##
##    #trace 1
##    # \
##    trace_1 = ( 1, [ (-10.0, -10.0), (-8.1, -8.0), (-6.2, -5.9), (-4.2, -4.1), (-2.0, -2.0) ] )
##    #trace 2
##    # /
##    trace_2 = ( 2, [ (-2.0, -10.0), (-4.1, -8.0), (-6.4, -5.9), (-7.8, -4.1), (-9.7, -2.0) ] )
##    #trace 3
##    # -
##    trace_3 = ( 3, [ (0.0, -7.0), (2.1, -6.9), (3.9, -7.1), (6.1, -7.0), (8.2,-7.1) ] )
##    #trace 4
##    # -
##    trace_4 = ( 4, [ (0.1, -3.0), (1.8, -3.9), (4.2, -3.1), (5.8, -3.0), (7.6,-3.1) ] )
##    #trace 5
##    # |
##    trace_5 = ( 5, [ (10.0, -9.8), (10.2, -7.9), (10.1, -6.1), (10.15, -4.2), (10.17, -2.3) ] )
##    
##    #group_x => X
##    group_x = [ trace_1, trace_2 ]
##
##    #group_eq => =
##    group_eq = [ trace_3, trace_4 ]
##
##    #group_1 => 1
##    group_1 = [trace_5 ]
##    
##    #classify group_x
##    confidences = classifier.classify( group_x )
##    label, conf = classifier.mostProbableLabel( confidences )
##    print( label + " => " + str(conf) )
##    #NOW THE TOP-3
##    top_3 = classifier.topNLabels( confidences, 3 )
##    print( top_3 )
##
##    #classify group_eq
##    confidences = classifier.classify( group_eq )
##    label, conf = classifier.mostProbableLabel( confidences )
##    print( label + " => " + str(conf) )    
##    #NOW THE TOP-3
##    top_3 = classifier.topNLabels( confidences, 3 )
##    print( top_3 )
##
##    #classify group_1
##    confidences = classifier.classify( group_1 )
##    label, conf = classifier.mostProbableLabel( confidences )
##    print( label + " => " + str(conf) )
##    #NOW THE TOP-3
##    top_3 = classifier.topNLabels( confidences, 3 )
##    print( top_3 )
##        
##    print( "DONE" )
##    
##main()
