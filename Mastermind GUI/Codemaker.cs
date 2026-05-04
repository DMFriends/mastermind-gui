using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace Mastermind_GUI
{
    public partial class Codemaker : Form
    {
        private int count = 0;
        public string[] Combination { get; set; } = new string[4];
        private readonly Codebreaker codebreaker;

        public Codemaker()
        {
            InitializeComponent();
            codebreaker = new Codebreaker(this);
        }

        private void CountButtons()
        {
            count++;

            if (count == 4)
            {
                this.Hide();
                codebreaker.ShowDialog();
            }
        }

        private void btnRed_Click(object sender, EventArgs e)
        {
            Combination[count] = "Red";
            CountButtons();
            btnRed.Enabled = false;
        }

        private void btnBlue_Click(object sender, EventArgs e)
        {
            Combination[count] = "Blue";
            CountButtons();
            btnBlue.Enabled = false;
        }

        private void btnGreen_Click(object sender, EventArgs e)
        {
            Combination[count] = "Green";
            CountButtons();
            btnGreen.Enabled = false;
        }

        private void btnWhite_Click(object sender, EventArgs e)
        {
            Combination[count] = "White";
            CountButtons();
            btnWhite.Enabled = false;
        }

        private void btnBlack_Click(object sender, EventArgs e)
        {
            Combination[count] = "Black";
            CountButtons();
            btnBlack.Enabled = false;
        }

        private void btnYellow_Click(object sender, EventArgs e)
        {
            Combination[count] = "Yellow";
            CountButtons();
            btnYellow.Enabled = false;
        }

        private void btnEndGame_Click(object sender, EventArgs e)
        {
            DialogResult result = MessageBox.Show("Are you sure you want to quit?", "Exit Game",
                MessageBoxButtons.YesNo, MessageBoxIcon.Warning);
            if (result == DialogResult.Yes)
            {
                Close();
            }
        }
    }
}
