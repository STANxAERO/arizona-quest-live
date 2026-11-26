import pathlib,sys,tempfile,unittest
from unittest.mock import patch
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/"macos"))
import maintenance as m

class MaintenanceTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path=pathlib.Path(self.tmp.name)/"state.json"
        self.p=patch.object(m,"STATE",self.path);self.p.start();self.addCleanup(self.p.stop)
    def state(self,**kwargs):
        m.write(self.path,dict(active="",previous="",candidate="v9.0",tested="",**kwargs))
    def test_untested_candidate_rejected(self):
        self.state()
        with self.assertRaises(RuntimeError):m.switch("activate")
        self.assertEqual(m.state()["active"],"")
    def test_changed_firmware_rejected(self):
        m.write(self.path,dict(active="",previous="",candidate="v9.0",tested="v9.0",tested_slot=0,tested_build="old"))
        with patch.object(m,"headset",return_value=("unused",{"build":"new"})):
            with self.assertRaises(RuntimeError):m.switch("activate")
        self.assertEqual(m.state()["active"],"")
    def test_activation_and_rollback(self):
        m.write(self.path,dict(active="v8.0",previous="",candidate="v9.0",tested="v9.0",tested_slot=0,tested_build="old"))
        with patch.object(m,"headset",return_value=("unused",{"build":"old"})),patch.object(m,"engine",side_effect=lambda x:x),patch.object(m,"run",return_value="ok"):
            m.switch("activate")
            self.assertEqual((m.state()["active"],m.state()["previous"]),("v9.0","v8.0"))
            m.switch("rollback")
            self.assertEqual(m.state()["active"],"v8.0")
if __name__=="__main__":unittest.main()
