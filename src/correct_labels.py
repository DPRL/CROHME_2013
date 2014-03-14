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

from numpy import *
import sys
import math
import pickle

def load_training_set( file_name ):
    try:
        file = open(file_name, 'r')        
        lines = file.readlines()
        file.close()

        #now process every line...
        #first line must be the attribute type for each feature...
        att_types_s = lines[0].split(';')
        att_types = [ s.strip().upper() for s in att_types_s ]

        #Number of rows = number of atts        
        t_rows = len(att_types)
        #Number of columns = total samples...
        t_columns = len(lines) - 1

        #create empty matrix to store all data...
        data = zeros((t_rows, t_columns))
        labels = []

        #the number of attributes must be consistent on every line, use the first as the model        
        for i in range(1, len(lines)):
            values_s = lines[i].split(';')

            #assume last value is class label
            labels.append( values_s[-1].strip() )

            #remove label from array...
            del values_s[-1]

            #validate number of attributes on the sample
            if len(att_types) != len(values_s):
                return False, False
            
            for k in range(len(att_types)):
                #Continuous value
                data[ k, i - 1] = float(values_s[k])            

        #return data array with its corresponding labels
        return data, labels
       
    except Exception as e:
        print( e )        
        return None, None

def getClassesList( labels ):
    all_classes = {}

    for label in labels:
        if not label in all_classes:
            all_classes[label] = True

    return all_classes.keys()
        

def write_training_set( file_name, data, labels ):
    #write the data set....
    t_file = open(file_name, 'w')

    #First, write the types of the attributes...
    header = ""
    for att in range(size(data, 0)):
        header += ("; " if att > 0 else "") + "C"

    header += '\r\n' 
    t_file.write(header)

    content = ''
    for i in range(size(data, 1)):
        line = ''

        for att in range(size(data, 0)):
            line += ("; " if att > 0 else "") + str(data[att, i])

        line += ("; " if size(data, 0) > 0 else "") + labels[i] + '\r\n'

        #add line to buffer    
        content += line
        
        if len(content) >= 50000:
            #buffer full, write....
            t_file.write(content)
            content = ''
        
    t_file.write(content)
    
    t_file.close()

def replace_labels( labels ):
    new_labels = []
    
    for label in labels:
        if label == '\'':
            new_label = '\prime'
        elif label == '>':
            new_label = '\gt'
        elif label == '<':
            new_label = '\lt'
        elif label == '\ldots':
            new_label = '\cdots'
        elif label == '\\vec':
            new_label = '\\rightarrow'
        elif label == '.':
            new_label = '\cdot'
        elif label == ',':
            new_label = 'COMMA'
        elif label == '\\frac':
            new_label = '-'
        else:
            #unchanged...
            new_label = label

        new_labels.append( new_label )

    return new_labels

def main():
    #usage check
    if len(sys.argv) != 3:
        print("Usage: python correct_labels.py training_set output_set ")
        print("Where")
        print("\ttraining_set\t= Path to the file of the training_set")        
        print("\toutput_set\t= File to output file with corrected labels")        
        return

    data, labels = load_training_set( sys.argv[1] )
    
    if data == None:
        print( "Data not could not be loaded" )
    else:
        #extract list of classes...
        all_classes = getClassesList( labels )

        print( "Original number of classes = " + str(len(all_classes)) )

        new_labels = replace_labels( labels )
        
        new_all_classes = getClassesList( new_labels )        
        print( "New number of classes = " + str(len(new_all_classes)) )
        
        write_training_set( sys.argv[2], data, new_labels )
        print( "Success!" )

main()

    
