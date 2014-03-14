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

import math

#This file represents the Decision tree itself, defined by nodes 
#that can be of three types:
#  1 - > Leafs
#  2 - > Decision nodes for continuous attributes (splits)
#  3 - > Decision nodes for discrete attributes
#  4 - > Decision nodes for clustered vectors  

class C45TreeNode:
    LEAF = 1
    CONTINUOUS = 2
    DISCRETE = 3
    VECTOR = 4
    
    def __init__(self, parent, own_class, samples_weights, samples_counts):
        self.parent = parent                #reference to parent      (None for root)        
        self.own_class = own_class          #owns node class          (required if leaf)        
        self.type = C45TreeNode.LEAF        #assume leaf by default
        self.samples_weights = samples_weights
        self.samples_counts = samples_counts            
        self.children = {}                  
        
        self.total_weight = 0.0
        self.total_count = 0
        for k in self.samples_weights:
            self.total_weight += self.samples_weights[k]
            self.total_count += self.samples_counts[k]
                                  
        
    def isLeaf(self):
        return len(self.children) == 0
            
    def setDecisionContinuous(self, attribute, threshold, ):
        self.type = C45TreeNode.CONTINUOUS    #continuous, single split
        self.attribute = attribute 
        self.threshold = threshold
        
    def setDecisionDiscrete(self, attribute, values ):
        self.type = C45TreeNode.DISCRETE
        self.attribute = attribute
        self.values = values
        
    def setDecisionVector(self, attribute, means):
        self.type = C45TreeNode.VECTOR
        self.attribute  = attribute
        self.means = means        
        
    def evaluate(self, sample):
        if self.type == C45TreeNode.LEAF:
            #leaf node reached...
            return self.own_class
        elif self.type == C45TreeNode.CONTINUOUS:
            #decision split for real values...            
            return self.children['0' if sample[ self.attribute ] <= self.threshold else '1'].evaluate( sample )            
        elif self.type == C45TreeNode.DISCRETE:
            #discrete values....
            if sample[self.attribute] in self.children:
                #go to corresponding children...                            
                return self.children[sample[self.attribute]].evaluate(sample)
            else:
                #unknown value for attribute, use majority class
                return self.own_class
        elif self.type == C45TreeNode.VECTOR:
            #check to which mean is closer...
            value = sample[self.attribute]
            
            closest = -1
            closest_dist = -1
            for k in range(len(self.means)):
                #get distance to mean k
                dist = 0
                for d in range(len(value)):
                    diff = (value[d] - self.means[k][d])
                    dist += diff * diff
                
                dist = math.sqrt(dist)
                
                #if it is closer ...
                if closest_dist < 0 or dist < closest_dist:
                    closest_dist = dist
                    closest = k
            
            #go to corresponding child...
            return self.children[str(closest)].evaluate(sample)
        
    def probabilistic_evaluate(self, sample):
        if self.type == C45TreeNode.LEAF:
            #leaf node reached...
            return self.samples_weights
        elif self.type == C45TreeNode.CONTINUOUS:
            #decision split for real values...  
            return self.children['0' if sample[ self.attribute ] <= self.threshold else '1'].probabilistic_evaluate( sample )            
        elif self.type == C45TreeNode.DISCRETE:
            #discrete values....
            if sample[self.attribute] in self.children:
                #go to corresponding children...                            
                return self.children[sample[self.attribute]].probabilistic_evaluate(sample)
            else:
                #unknown value for attribute, use majority class
                return self.samples_weights
        elif self.type == C45TreeNode.VECTOR:
            #check to which mean is closer...
            value = sample[self.attribute]
            
            closest = -1
            closest_dist = -1
            for k in range(len(self.means)):
                #get distance to mean k
                dist = 0
                for d in range(len(value)):
                    diff = (value[d] - self.means[k][d])
                    dist += diff * diff
                
                dist = math.sqrt(dist)
                
                #if it is closer ...
                if closest_dist < 0 or dist < closest_dist:
                    closest_dist = dist
                    closest = k
            
            #go to corresponding child...
            return self.children[str(closest)].probabilistic_evaluate(sample)        
    
    def setChildren(self, key, node):
        self.children[key] = node
    
    def __str__(self):
        return self.recursiveString("", "")
    
    def cleanChildTag(self):
        #for debugging purposes, trim the string for the children 
        new_children = {}
        for k in self.children:
            new_children[k.strip()] = self.children[k]
            #call recursively
            new_children[k.strip()].cleanChildTag()
            
        self.children = new_children
    
    def recursiveString(self, leftPadding, extra):
        if self.type == C45TreeNode.VECTOR:
            #VECTOR...
            result = leftPadding + extra + "Att (" + str(self.attribute) + "), Vector \r\n"
            for k in self.children:                
                result += self.children[k].recursiveString(leftPadding + "  ", str(self.means[int(k)]) + ": " )
        elif self.type == C45TreeNode.DISCRETE:
            #discrete
            result = leftPadding + extra + "Att (" + str(self.attribute) + "), Discrete \r\n"
            for k in self.children:
                result += self.children[k].recursiveString(leftPadding + "  ", k + ": " )
        elif self.type == C45TreeNode.CONTINUOUS:
            #decision node
            result = leftPadding + extra + "Att (" + str(self.attribute) + "), Threshold = " + str(self.threshold) + '\r\n'
            
            if '0' in self.children:
                result += self.children['0'].recursiveString(leftPadding + "  ", "<= " )
            if '1' in self.children:
                result += self.children['1'].recursiveString(leftPadding + "  ", ">  " )
        else:
            #leaf
            result = leftPadding + extra + " CLASS (" + str(self.own_class) + ") " + str(self.samples_counts) + " \r\n"
            
            
        return result
    
    
