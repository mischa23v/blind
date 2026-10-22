import unittest
from fresh_benchmark import make_protocol, summarize, select_policy

class FreshProtocolTests(unittest.TestCase):
    def test_split_disjoint(self):
        names = [f'person{chr(97+i)}{j}.jpg' for i in range(26) for j in range(1,5)]
        protocol = make_protocol(names)
        a, b = protocol['phases'].values()
        self.assertFalse(set(a['identities']) & set(b['identities']))
        self.assertFalse({r['image'] for r in a['observations']} & {r['image'] for r in b['observations']})
        self.assertEqual(sum(r['enrollment'] for r in a['observations']),10)
        self.assertEqual(len(a['observations']),52)
    def test_uncertain_names_excluded(self):
        names = ['one1.jpg','one2.jpg','one3.jpg','one4.jpg','one!22.jpg','one16a.jpg','hack.jpg','single1.jpg']
        protocol = make_protocol(names)
        self.assertEqual(protocol['excludedImages'], ['hack.jpg','one!22.jpg','one16a.jpg','single1.jpg'])
    def test_clean_alias_excluded_even_if_multiple(self):
        protocol = make_protocol([f'clean_adrian{i}.jpg' for i in range(1,5)])
        self.assertEqual(len(protocol['excludedImages']),4)
    def test_lowest_number_enrolls(self):
        protocol = make_protocol(['a10.jpg','a2.jpg','a3.jpg','a4.jpg'])
        self.assertEqual(protocol['phases']['calibration']['observations'][0]['image'],'a2.jpg')
        self.assertTrue(protocol['phases']['calibration']['observations'][0]['enrollment'])
    def test_missed_detection_keeps_denominator(self):
        rows = [{'identity':'a','known':True,'image':'a2','ranking':[]}, {'identity':'b','known':False,'image':'b1','ranking':[]}]
        result=summarize(rows,.363,.1)
        self.assertEqual(result['knownAbstain']['numerator'],1)
        self.assertEqual(result['unknownAbstain']['numerator'],1)
    def test_unknown_collision_and_known_error(self):
        rows=[{'identity':'a','known':True,'image':'a2','ranking':[('wrong',.9),('a',.1)]}, {'identity':'b','known':False,'image':'b1','ranking':[('a',.9),('other',.1)]}]
        result=summarize(rows,.363,.1)
        self.assertEqual(result['knownWrong']['numerator'],1)
        self.assertEqual(result['unknownFalseIdentification']['numerator'],1)
        self.assertEqual(result['unknownIdentitiesWithAnyFalseIdentification']['numerator'],1)
    def test_selection_minimizes_errors_before_coverage(self):
        def row(threshold, errors, correct):
            return {'threshold':threshold,'margin':.1,'result':{'unknownFalseIdentification':{'numerator':errors},'knownWrong':{'numerator':0},'knownCorrect':{'numerator':correct}}}
        self.assertEqual(select_policy([row(.3,1,100),row(.5,0,90),row(.6,0,90)]),{'threshold':.6,'margin':.1})

if __name__=='__main__':unittest.main()
